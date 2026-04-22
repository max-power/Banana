require "zlib"

class TilesController < ApplicationController
  before_action :authenticate!

  TILE_SIZE = 256

  def show
    z, x, y = params.values_at(:z, :x, :y).map(&:to_i)

    respond_to do |format|
      format.png do
        scope = ActivityTile.joins(:activity).where(user_id: Current.user.id, z: z, x: x, y: y)
        scope = scope.where(start_year: params[:year].to_i) if params[:year].present?
        scope = scope.where(activities: { activity_type: params[:type] }) if params[:type].present?

        rows = scope.pluck(:pixels)
        return head :no_content if rows.empty?

        buffer = Array.new(TILE_SIZE * TILE_SIZE, 0)
        rows.each do |blob|
          Zlib::Inflate.inflate(blob).unpack("S>*").each do |idx|
            buffer[idx] = [ buffer[idx] + 1, 255 ].min
          end
        end

        gradient = HeatmapPalette.find(params[:palette])
        send_data encode_png(buffer, gradient), type: "image/png", disposition: "inline"
      end
    end
  end

  private

  def encode_png(buffer, gradient)
    row_stride = TILE_SIZE * 4 + 1
    raw        = "\x00".b * (TILE_SIZE * row_stride)

    TILE_SIZE.times do |y|
      TILE_SIZE.times do |x|
        val = buffer[y * TILE_SIZE + x]
        next if val.zero?
        r, g, b, a = gradient[val]
        offset = y * row_stride + 1 + x * 4
        raw.setbyte(offset,     r)
        raw.setbyte(offset + 1, g)
        raw.setbyte(offset + 2, b)
        raw.setbyte(offset + 3, a)
      end
    end

    png  = "\x89PNG\r\n\x1a\n".b
    png << png_chunk("IHDR", [ TILE_SIZE, TILE_SIZE, 8, 6, 0, 0, 0 ].pack("N2C5"))
    png << png_chunk("IDAT", Zlib::Deflate.deflate(raw, Zlib::BEST_SPEED))
    png << png_chunk("IEND", "")
    png
  end

  def png_chunk(type, data)
    data   = data.b
    type_b = type.b
    [ data.bytesize ].pack("N") + type_b + data + [ Zlib.crc32(type_b + data) ].pack("N")
  end
end
