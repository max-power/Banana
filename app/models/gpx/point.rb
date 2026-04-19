module GPX
  Point = Data.define(:lat, :lon, :elevation, :time, :meta) do
    ZERO_EPSILON = 1e-6

    def self.from_xml(node)
      x = node[:lat].to_f
      y = node[:lon].to_f
      z = node.at_xpath("ele")&.text.to_f || 0.0
      t = Time.iso8601(node.at_xpath("time")&.text).to_f rescue nil
      m =  {}
      new(x, y, z, t, m)
    end

    def zero?
      lat < ZERO_EPSILON && lon < ZERO_EPSILON
    end

    def distance_to(other)
      Haversine.distance(lat, lon, other.lat, other.lon).to_meters
    end

    def time_difference_to(other)
      (time - other.time).abs if time && other.time
    end

    def to_rgeo_point
      Geo.point(lon, lat, elevation)
    end

    def to_coordinates
      [lat, lon, elevation]
    end
  end
end
