class Geo
  SRID = 4326

  def self.factory
#    @@factory ||= RGeo::Geographic.spherical_factory(srid: SRID)
    @@factory ||= RGeo::Cartesian.preferred_factory(has_z_coordinate: true, srid: SRID)
  end

  def self.point(longitude, latitude, elevation=nil)
    factory.point(longitude, latitude, elevation)
  end

  def self.line_string(points)
    factory.line_string(points)
  end

  def self.polygon(points)
    factory.polygon(line_string(points))
  end

  def self.to_wkt(feature)
    "srid=#{SRID};#{feature}"
  end
end
