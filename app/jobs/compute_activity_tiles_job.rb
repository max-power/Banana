require "zlib"
require "json"

class ComputeActivityTilesJob < ApplicationJob
  queue_as :default

  TILE_SIZE  = 256
  EARTH_HALF = 20037508.342789244
  MAX_ZOOM   = 16

  SIMPLIFY_BY_ZOOM = [
    [0..9,  200],
    [10..13, 50],
    [14..16,  0],
  ].freeze

  MIN_LENGTH_BY_ZOOM = [
    [0..7,  500],
    [8..10, 100],
  ].freeze

  def perform(activity_id, min_zoom: 0)
    activity = Activity.where(type: nil).find_by(id: activity_id)
    return unless activity

    ActivityTile.where(activity_id: activity_id, z: (min_zoom..MAX_ZOOM)).delete_all

    (min_zoom..MAX_ZOOM).each do |z|
      # Ask PostGIS which tiles the route actually passes through — no more
      # bounding-box rectangle that includes empty corner tiles.
      tiles = tiles_covered_by(activity_id, z)
      next if tiles.empty?

      segments = fetch_segments(activity_id, z)
      next if segments.empty?

      # Index coordinate pairs by tile so render_pixels only sees pairs that
      # could actually affect the tile it's rendering, not the entire activity.
      tile_pairs = build_tile_index(segments, z)

      rows = tiles.filter_map do |x, y|
        pairs = tile_pairs[[x, y]]
        next unless pairs&.any?

        pixels = render_pixels(pairs, z, x, y)
        next if pixels.empty?

        {
          activity_id: activity_id,
          user_id:     activity.user_id,
          z:           z,
          x:           x,
          y:           y,
          start_year:  activity.start_time&.year,
          pixels:      compress(pixels),
          created_at:  Time.current,
          updated_at:  Time.current,
        }
      end

      ActivityTile.insert_all(rows) if rows.any?
    end
  end

  private

  # Returns [[x, y], ...] for every tile the activity actually passes through.
  # Densifies the geometry with ST_Segmentize (step = half a tile width) so
  # that no tile is missed even for long diagonal segments.
  def tiles_covered_by(activity_id, z)
    n          = 2 ** z
    tile_size  = EARTH_HALF * 2.0 / n
    step       = tile_size / 2.0
    tolerance  = zoom_tolerance(z)
    min_length = zoom_min_length(z)
    simplify   = tolerance > 0 ? "ST_Simplify(geom_3857, #{tolerance})" : "geom_3857"

    sql = <<~SQL
      WITH segs AS (
        SELECT #{simplify} AS geom
        FROM   activity_segments
        WHERE  activity_id = $1
          AND  ST_Length(geom_3857) > #{min_length}
      )
      SELECT DISTINCT
        GREATEST(0, LEAST(floor((ST_X(dp.geom) + #{EARTH_HALF}) / #{tile_size})::int, #{n - 1})) AS x,
        GREATEST(0, LEAST(floor((#{EARTH_HALF} - ST_Y(dp.geom)) / #{tile_size})::int, #{n - 1})) AS y
      FROM   segs,
             LATERAL ST_DumpPoints(ST_Segmentize(segs.geom, #{step})) AS dp(path, geom)
      WHERE  ST_NPoints(segs.geom) >= 2
        AND  NOT ST_IsEmpty(segs.geom)
    SQL

    connection.exec_query(sql, "tiles_for_z#{z}", [ activity_id ])
              .map { |r| [ r["x"], r["y"] ] }
  end

  # Fetch simplified geometry as coordinate arrays for Ruby-side rasterisation.
  def fetch_segments(activity_id, z)
    tolerance  = zoom_tolerance(z)
    min_length = zoom_min_length(z)
    simplify   = tolerance > 0 ? "ST_Simplify(geom_3857, #{tolerance})" : "geom_3857"

    connection.exec_query(<<~SQL, "segments_for_z#{z}", [ activity_id ])
      SELECT ST_AsGeoJSON(#{simplify}) AS coords
      FROM   activity_segments
      WHERE  activity_id = $1
        AND  ST_Length(geom_3857) > #{min_length}
    SQL
    .flat_map { |r| parse_lines(r["coords"]) }
    .reject(&:empty?)
  end

  def parse_lines(geojson_str)
    return [] unless geojson_str
    geo = JSON.parse(geojson_str)
    case geo["type"]
    when "LineString"      then [ geo["coordinates"] ]
    when "MultiLineString" then geo["coordinates"]
    else []
    end
  end

  # Build a Hash of { [tx, ty] => [pair, pair, ...] } so each tile's
  # render_pixels only processes coordinate pairs that could cross it.
  # A pair is assigned to all tiles its bounding box touches — the
  # Liang-Barsky clip in render_pixels will handle exact rejection.
  def build_tile_index(segments, z)
    n         = 2 ** z
    tile_size = EARTH_HALF * 2.0 / n
    index     = Hash.new { |h, k| h[k] = [] }

    segments.each do |coords|
      coords.each_cons(2) do |pair|
        (x1, y1, *), (x2, y2, *) = pair
        tx1 = ((x1 + EARTH_HALF) / tile_size).floor.clamp(0, n - 1)
        ty1 = ((EARTH_HALF - y1) / tile_size).floor.clamp(0, n - 1)
        tx2 = ((x2 + EARTH_HALF) / tile_size).floor.clamp(0, n - 1)
        ty2 = ((EARTH_HALF - y2) / tile_size).floor.clamp(0, n - 1)
        ([tx1, tx2].min..[tx1, tx2].max).each do |tx|
          ([ty1, ty2].min..[ty1, ty2].max).each do |ty|
            index[[tx, ty]] << pair
          end
        end
      end
    end

    index
  end

  # Rasterise the coordinate pairs that cross tile (x, y) into a 256×256 grid.
  # Uses a Set instead of a byte-array scan — O(pixels_drawn) not O(65536).
  def render_pixels(pairs, z, x, y)
    n    = 2 ** z
    size = EARTH_HALF * 2.0 / n
    xmin = -EARTH_HALF + x * size
    ymax =  EARTH_HALF - y * size

    pixel_set = Set.new

    pairs.each do |(x1, y1, *), (x2, y2, *)|
      px1 = ((x1 - xmin) / size * TILE_SIZE).round
      py1 = ((ymax - y1) / size * TILE_SIZE).round
      px2 = ((x2 - xmin) / size * TILE_SIZE).round
      py2 = ((ymax - y2) / size * TILE_SIZE).round
      clipped = clip(px1, py1, px2, py2)
      bresenham(pixel_set, *clipped) if clipped
    end

    pixel_set.to_a
  end

  # Liang-Barsky line clipping to [0, TILE_SIZE-1]
  def clip(x0, y0, x1, y1)
    max = TILE_SIZE - 1
    dx  = x1 - x0
    dy  = y1 - y0
    p   = [ -dx,  dx, -dy,  dy ]
    q   = [  x0, max - x0, y0, max - y0 ]
    t0  = 0.0
    t1  = 1.0

    p.each_with_index do |pi, i|
      if pi == 0
        return nil if q[i] < 0
      elsif pi < 0
        t0 = [ t0, q[i].to_f / pi ].max
      else
        t1 = [ t1, q[i].to_f / pi ].min
      end
    end

    return nil if t0 > t1

    [ (x0 + t0 * dx).round, (y0 + t0 * dy).round,
      (x0 + t1 * dx).round, (y0 + t1 * dy).round ]
  end

  def bresenham(pixel_set, x0, y0, x1, y1)
    dx = (x1 - x0).abs
    dy = -(y1 - y0).abs
    sx = x0 < x1 ? 1 : -1
    sy = y0 < y1 ? 1 : -1
    err = dx + dy

    loop do
      pixel_set.add(y0 * TILE_SIZE + x0)
      break if x0 == x1 && y0 == y1
      e2 = 2 * err
      if e2 >= dy
        break if x0 == x1
        err += dy; x0 += sx
      end
      if e2 <= dx
        break if y0 == y1
        err += dx; y0 += sy
      end
    end
  end

  def compress(pixel_indices)
    Zlib::Deflate.deflate(pixel_indices.pack("S>*"), Zlib::BEST_SPEED)
  end

  def zoom_tolerance(z)
    SIMPLIFY_BY_ZOOM.find { |range, _| range.include?(z) }&.last || 0
  end

  def zoom_min_length(z)
    MIN_LENGTH_BY_ZOOM.find { |range, _| range.include?(z) }&.last || 0
  end

  def connection
    ActiveRecord::Base.connection
  end
end
