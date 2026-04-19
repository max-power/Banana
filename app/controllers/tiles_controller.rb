require "zlib"
require "json"

class TilesController < ApplicationController
  before_action :authenticate!

  TILE_SIZE = 256
  EARTH_HALF = 20037508.342789244

  def show
    tile = Tile.new(*params.values_at(:z, :x, :y).map(&:to_i))

    respond_to do |format|
      format.png { render_raster_tile(tile) }
    end
  end

  private

  def render_raster_tile(tile)
    cache_key = "tiles/v4/#{Current.user.id}/#{year_param || 'all'}/#{month_param || 'all'}/#{tile.cache_key}"

    png = Rails.cache.fetch(cache_key, expires_in: 24.hours, skip_nil: true) do
      generate_tile_png(tile)
    rescue => e
      Rails.logger.error "Tile render failed #{tile.z}/#{tile.x}/#{tile.y}: #{e.class} #{e.message}"
      nil
    end

    if png
      send_data png, type: "image/png", disposition: "inline"
    else
      head :no_content
    end
  end

  def generate_tile_png(tile)
    xmin, ymin, xmax, ymax = tile_bounds(tile.z, tile.x, tile.y)
    tile_w = xmax - xmin
    tile_h = ymax - ymin

    result = ActiveRecord::Base.connection.exec_query(
      segments_sql, "tile_segments",
      [ tile.z, tile.x, tile.y, Current.user.id, year_param, month_param ]
    )
    return nil if result.empty?

    buffer = Array.new(TILE_SIZE * TILE_SIZE, 0)

    result.each do |row|
      geojson = JSON.parse(row["coords"])
      lines = case geojson["type"]
      when "LineString"     then [ geojson["coordinates"] ]
      when "MultiLineString" then geojson["coordinates"]
      else next
      end

      lines.each do |coords|
        coords.each_cons(2) do |(x1, y1, *), (x2, y2, *)|
          px1 = ((x1 - xmin) / tile_w * TILE_SIZE).round.clamp(0, TILE_SIZE - 1)
          py1 = ((ymax - y1) / tile_h * TILE_SIZE).round.clamp(0, TILE_SIZE - 1)
          px2 = ((x2 - xmin) / tile_w * TILE_SIZE).round.clamp(0, TILE_SIZE - 1)
          py2 = ((ymax - y2) / tile_h * TILE_SIZE).round.clamp(0, TILE_SIZE - 1)
          draw_line(buffer, px1, py1, px2, py2)
        end
      end
    end

    return nil if buffer.all?(&:zero?)

    max_val = buffer.max.to_f
    encode_png(buffer, max_val)
  end

  # Bresenham line drawing — increments the pixel counter for each lit pixel.
  # Guards against overshooting endpoints which causes out-of-bounds buffer access.
  def draw_line(buffer, x0, y0, x1, y1)
    dx = (x1 - x0).abs
    dy = -(y1 - y0).abs
    sx = x0 < x1 ? 1 : -1
    sy = y0 < y1 ? 1 : -1
    err = dx + dy

    loop do
      buffer[y0 * TILE_SIZE + x0] += 1
      break if x0 == x1 && y0 == y1
      e2 = 2 * err
      if e2 >= dy
        break if x0 == x1
        err += dy
        x0 += sx
      end
      if e2 <= dx
        break if y0 == y1
        err += dx
        y0 += sy
      end
    end
  end

  # Encodes pixel buffer as a transparent RGBA PNG using stdlib zlib.
  # Uses setbyte to avoid per-pixel string allocation.
  def encode_png(buffer, max_val)
    row_stride = TILE_SIZE * 4 + 1
    raw = "\x00".b * (TILE_SIZE * row_stride)

    TILE_SIZE.times do |y|
      TILE_SIZE.times do |x|
        val = buffer[y * TILE_SIZE + x]
        next if val.zero?
        t = (val / max_val).clamp(0.0, 1.0)
        offset = y * row_stride + 1 + x * 4
        raw.setbyte(offset,     85)
        raw.setbyte(offset + 1,  0)
        raw.setbyte(offset + 2, 245)
        raw.setbyte(offset + 3, (t * 200 + 55).to_i)
      end
    end

    png = "\x89PNG\r\n\x1a\n".b
    png << png_chunk("IHDR", [ TILE_SIZE, TILE_SIZE, 8, 6, 0, 0, 0 ].pack("N2C5"))
    png << png_chunk("IDAT", Zlib::Deflate.deflate(raw, Zlib::BEST_SPEED))
    png << png_chunk("IEND", "")
    png
  end

  def png_chunk(type, data)
    data = data.b
    type_b = type.b
    [ data.bytesize ].pack("N") + type_b + data + [ Zlib.crc32(type_b + data) ].pack("N")
  end

  def tile_bounds(z, x, y)
    size = EARTH_HALF * 2 / (2**z)
    xmin = -EARTH_HALF + x * size
    xmax = xmin + size
    ymax = EARTH_HALF - y * size
    ymin = ymax - size
    [ xmin, ymin, xmax, ymax ]
  end

  def segments_sql
    <<~SQL
      SELECT ST_AsGeoJSON(
        CASE
          WHEN $1 < 10 THEN ST_Simplify(geom, 200)
          WHEN $1 < 14 THEN ST_Simplify(geom, 50)
          ELSE ST_Simplify(geom, 20)
      END
      ) AS coords
      FROM activity_segments_mvts
      WHERE geom && ST_TileEnvelope($1, $2, $3)
      AND zoom_level = $1
      AND user_id = $4
      AND ($5::int IS NULL OR EXTRACT(YEAR  FROM start_date)::int = $5::int)
      AND ($6::int IS NULL OR EXTRACT(MONTH FROM start_date)::int = $6::int)
    SQL
  end

  def year_param  = params[:year].presence&.to_i
    def month_param = params[:month].presence&.to_i
    end
