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
      segments = fetch_segments(activity_id, z)
      next if segments.empty?

      tiles = tiles_covered_by(segments, z)
      rows  = []

      tiles.each do |x, y|
        pixels = render_pixels(segments, z, x, y)
        next if pixels.empty?

        rows << {
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

  def fetch_segments(activity_id, z)
    tolerance   = SIMPLIFY_BY_ZOOM.find { |range, _| range.include?(z) }&.last || 0
    min_length  = MIN_LENGTH_BY_ZOOM.find { |range, _| range.include?(z) }&.last || 0
    simplify_fn = tolerance > 0 ? "ST_Simplify(geom_3857, #{tolerance})" : "geom_3857"

    result = ActiveRecord::Base.connection.exec_query(<<~SQL, "segments_for_z", [ activity_id ])
      SELECT ST_AsGeoJSON(#{simplify_fn}) AS coords
      FROM activity_segments
      WHERE activity_id = $1
      AND ST_Length(geom_3857) > #{min_length}
    SQL

    result.map { |r| parse_lines(r["coords"]) }.flatten(1).reject(&:empty?)
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

  def tiles_covered_by(segments, z)
    n    = 2**z
    size = EARTH_HALF * 2 / n
    xs, ys = [], []

    segments.each do |coords|
      coords.each do |x, y, *|
        xs << ((x + EARTH_HALF) / size).floor.clamp(0, n - 1)
        ys << ((EARTH_HALF - y) / size).floor.clamp(0, n - 1)
      end
    end

    return [] if xs.empty?
    (xs.min..xs.max).flat_map { |x| (ys.min..ys.max).map { |y| [ x, y ] } }
  end

  def render_pixels(segments, z, x, y)
    n    = 2**z
    size = EARTH_HALF * 2 / n
    xmin = -EARTH_HALF + x * size
    xmax = xmin + size
    ymax = EARTH_HALF - y * size
    ymin = ymax - size
    tw   = xmax - xmin
    th   = ymax - ymin

    buffer = Array.new(TILE_SIZE * TILE_SIZE, false)

    segments.each do |coords|
      coords.each_cons(2) do |(x1, y1, *), (x2, y2, *)|
        px1 = ((x1 - xmin) / tw * TILE_SIZE).round
        py1 = ((ymax - y1) / th * TILE_SIZE).round
        px2 = ((x2 - xmin) / tw * TILE_SIZE).round
        py2 = ((ymax - y2) / th * TILE_SIZE).round
        clipped = clip(px1, py1, px2, py2)
        bresenham(buffer, *clipped) if clipped
      end
    end

    buffer.each_index.select { |i| buffer[i] }
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

  def bresenham(buffer, x0, y0, x1, y1)
    dx = (x1 - x0).abs
    dy = -(y1 - y0).abs
    sx = x0 < x1 ? 1 : -1
    sy = y0 < y1 ? 1 : -1
    err = dx + dy

    loop do
      buffer[y0 * TILE_SIZE + x0] = true
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
end
