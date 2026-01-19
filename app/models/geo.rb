class Geo
    SRID = 4326

    def self.factory
        # Cartesian factory with Z coordinate
        @@factory ||= RGeo::Geographic.spherical_factory(srid: SRID, has_z_coordinate: true)
    end

    def self.point(longitude, latitude, elevation = nil)
        factory.point(longitude, latitude, elevation)
    end

    def self.line_string(points)
        factory.line_string(points)
    end

    def self.multi_line_string(lines)
        factory.multi_line_string(lines)
    end

    def self.polygon(points)
        factory.polygon(line_string(points))
    end

    def self.to_wkt(feature)
        "SRID=#{SRID};#{feature.as_text}"
    end
end
