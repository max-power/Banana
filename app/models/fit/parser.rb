module FIT
  class Parser
    attr_reader :records, :session, :device, :utc_offset

    def initialize(data)
      @data        = data.b  # force binary encoding
      @pos         = 0
      @definitions = {}      # local_msg_type => definition hash
      @records     = []
      @session     = {}
      @device      = nil
      @utc_offset  = nil
    end

    def parse
      read_header
      read_record until @pos >= @data_end
      self
    rescue => e
      Rails.logger.warn "FIT parse error at byte #{@pos}: #{e.message}"
      self
    end

    private

    def read_header
      header_size = @data.getbyte(0)
      raise "Not a FIT file" unless @data.byteslice(8, 4) == ".FIT"
      data_size   = @data.byteslice(4, 4).unpack1("L<")
      @data_end   = header_size + data_size
      @pos        = header_size
    end

    def read_record
      hdr = @data.getbyte(@pos); @pos += 1

      if hdr & 0x80 != 0
        # Compressed timestamp header — bits 5-6 are local type, bits 0-4 are time offset
        read_data_message((hdr >> 5) & 0x03)
      elsif hdr & 0x40 != 0
        # Definition message — bit 5 signals developer fields
        read_definition_message(hdr & 0x0F, hdr & 0x20 != 0)
      else
        # Data message
        read_data_message(hdr & 0x0F)
      end
    end

    def read_definition_message(local_type, has_dev_fields)
      @pos += 1  # reserved byte
      big_endian = @data.getbyte(@pos) == 1; @pos += 1
      global_msg = @data.byteslice(@pos, 2).unpack1(big_endian ? "S>" : "S<"); @pos += 2
      num_fields = @data.getbyte(@pos); @pos += 1

      fields = Array.new(num_fields) do
        f = { num: @data.getbyte(@pos), size: @data.getbyte(@pos + 1), base_type: @data.getbyte(@pos + 2) }
        @pos += 3
        f
      end

      dev_data_size = 0
      if has_dev_fields
        num_dev = @data.getbyte(@pos); @pos += 1
        num_dev.times do
          dev_data_size += @data.getbyte(@pos + 1)  # byte 1 of each dev field def is the size
          @pos += 3
        end
      end

      @definitions[local_type] = { global_msg: global_msg, big_endian: big_endian, fields: fields, dev_data_size: dev_data_size }
    end

    def read_data_message(local_type)
      defn = @definitions[local_type]

      unless defn
        # No definition seen yet for this local type — file may be corrupt or unsupported
        Rails.logger.warn "FIT: no definition for local_type=#{local_type} at pos=#{@pos}"
        @pos = @data_end
        return
      end

      values = {}
      defn[:fields].each do |field|
        raw = @data.byteslice(@pos, field[:size])
        @pos += field[:size]
        val = decode_field(raw, field[:base_type], field[:size], defn[:big_endian])
        values[field[:num]] = val unless val.nil?
      end

      # Skip any developer field data appended after regular fields
      @pos += defn[:dev_data_size]

      case defn[:global_msg]
      when 20 then handle_record(values)
      when 18 then handle_session(values)
      when 34 then handle_activity(values)
      when  0 then handle_file_id(values)
      when 23 then handle_device_info(values)
      end
    end

    def decode_field(raw, base_type_byte, size, big_endian)
      bt = BASE_TYPES[base_type_byte]
      return nil unless bt

      byte_size, fmt_le, fmt_be, invalid = bt

      # String: strip null terminator and return
      if base_type_byte == 0x07
        str = raw.unpack1("a#{size}").delete("\x00")
        return str.empty? ? nil : str
      end

      # Array field (size > base size): only decode the first element
      raw = raw.byteslice(0, byte_size) if size > byte_size && byte_size > 0

      val = raw.unpack1(big_endian ? fmt_be : fmt_le)
      val == invalid ? nil : val
    end

    # Record message (global msg 20) — one GPS track point
    def handle_record(v)
      lat = v[0]; lon = v[1]
      return unless lat && lon

      lat *= SEMICIRCLES
      lon *= SEMICIRCLES
      return if lat.abs < 1e-6 && lon.abs < 1e-6  # (0,0) is invalid

      # Enhanced altitude (field 53) preferred over altitude (field 2); scale=5, offset=500
      alt = v[53] || v[2]
      alt = alt ? (alt / 5.0) - 500.0 : nil
      alt = nil if alt && (alt < -500 || alt > 9000)

      ts = v[253]&.+(FIT_EPOCH)

      @records << Track::Point.new(lat: lat, lon: lon, elevation: alt, time: ts)
    end

    # Activity message (global msg 34) — local_timestamp (field 5) lets us compute UTC offset
    def handle_activity(v)
      utc_ts   = v[253]
      local_ts = v[5]
      @utc_offset = (local_ts - utc_ts).round if utc_ts && local_ts
    end

    # Session message (global msg 18) — overall activity summary
    def handle_session(v)
      @session = {
        sport:          v[5],
        start_time:     v[2]&.+(FIT_EPOCH),
        elapsed_time_s: v[7]&./(1000.0),   # total_elapsed_time (ms → s)
        moving_time_s:  v[8]&./(1000.0),   # total_timer_time (ms → s)
        distance_m:     v[9]&./(100.0),     # total_distance (cm → m)
        total_ascent:   v[22],              # uint16, already in meters
        avg_speed_m_s:  v[14]&./(1000.0),  # mm/s → m/s
        max_speed_m_s:  v[15]&./(1000.0),  # mm/s → m/s
      }
    end

    # file_id message (global msg 0) — identifies the recording device
    def handle_file_id(v)
      # Field 8: product_name (string) — present on newer devices, most reliable
      # Field 1: manufacturer (uint16), Field 2: product (uint16) — fallback
      name = v[8].presence
      unless name
        brand = MANUFACTURERS[v[1]]
        name  = brand || (v[1] ? "Device ##{v[1]}" : nil)
      end
      @device ||= name
    end

    # device_info message (global msg 23) — describes connected sensors/primary unit
    def handle_device_info(v)
      return if @device                     # file_id already provided a name
      return unless v[0] == 0              # device_index 0 = main recording unit
      name = v[27].presence                # field 27: product_name
      unless name
        brand = MANUFACTURERS[v[2]]        # field 2: manufacturer
        name  = brand || (v[2] ? "Device ##{v[2]}" : nil)
      end
      @device ||= name
    end
  end
end
