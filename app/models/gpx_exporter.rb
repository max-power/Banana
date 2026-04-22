class GPXExporter
  def initialize(activity)
    @activity = activity
  end

  def to_gpx
    segments = @activity.activity_segments.order(:segment_index)

    builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
      xml.gpx(
        version: "1.1",
        creator: "Banana",
        xmlns: "http://www.topografix.com/GPX/1/1",
        "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
        "xsi:schemaLocation": "http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
      ) do
        xml.metadata do
          xml.name @activity.name if @activity.name.present?
          xml.time @activity.start_time.iso8601 if @activity.start_time
        end
        xml.trk do
          xml.name @activity.name if @activity.name.present?
          xml.type @activity.activity_type if @activity.activity_type.present?
          segments.each do |segment|
            xml.trkseg do
              points_for(segment).each do |lng, lat, ele|
                xml.trkpt(lat: lat.round(7), lon: lng.round(7)) do
                  xml.ele ele.round(2) if ele
                end
              end
            end
          end
        end
      end
    end

    builder.to_xml
  end

  private

  def points_for(segment)
    result = ActiveRecord::Base.connection.exec_query(<<~SQL, "gpx_export_points", [ segment.id ])
      SELECT
        ST_X(ST_Transform(dp.geom, 4326)) AS lng,
        ST_Y(ST_Transform(dp.geom, 4326)) AS lat,
        ST_Z(ST_Transform(dp.geom, 4326)) AS ele
      FROM (
        SELECT (ST_DumpPoints(geom)).geom
        FROM activity_segments
        WHERE id = $1
      ) dp
    SQL
    result.map { |r| [ r["lng"], r["lat"], r["ele"] ] }
  end
end
