begin
  require "gd/gis"
  GD_GIS_AVAILABLE = true
rescue LoadError
  GD_GIS_AVAILABLE = false
end

class StaticMapService
  def self.available? = GD_GIS_AVAILABLE
  WIDTH   = 1200
  HEIGHT  = 630
  PADDING = 0.08  # fraction of bbox range to pad on each side

  STYLE = GD::GIS::Style.new({
    global: { label: false },
    order:  [],
  })

  TRACK_COLOR = GD::Color.rgba(255, 51, 85, 0)
  TRACK_WIDTH = 6

  def initialize(activity)
    @activity = activity
  end

  def render
    geometry = parse_geometry
    return nil unless geometry

    coords = flatten_coords(geometry)
    return nil if coords.size < 2

    lons = coords.map { |c| c[0] }
    lats = coords.map { |c| c[1] }
    lon_min, lon_max = lons.minmax
    lat_min, lat_max = lats.minmax

    lon_range = [lon_max - lon_min, 0.001].max
    lat_range = [lat_max - lat_min, 0.001].max

    bbox = [
      lon_min - lon_range * PADDING,
      lat_min - lat_range * PADDING,
      lon_max + lon_range * PADDING,
      lat_max + lat_range * PADDING,
    ]

    zoom = auto_zoom(lon_range, lat_range)

    lines = linestrings(geometry).map { |line| line.map { |c| [c[0], c[1]] } }

    map = GD::GIS::Map.new(bbox: bbox, zoom: zoom, basemap: :esri_terrain,
                           width: WIDTH, height: HEIGHT)
    map.style = STYLE
    map.render

    viewport_bbox = GD::GIS::Geometry.viewport_bbox(bbox: bbox, zoom: zoom, width: WIDTH, height: HEIGHT)
    map.image.antialias = true
    lines.each do |line|
      pts = line.map { |lng, lat| GD::GIS::Geometry.project(lng, lat, viewport_bbox, zoom) }
      pts.each_cons(2) do |a, b|
        map.image.line(a[0].round, a[1].round, b[0].round, b[1].round, TRACK_COLOR, thickness: TRACK_WIDTH)
      end
    end

    map.image.to_png
  rescue Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, SocketError => e
    Rails.logger.warn "StaticMapService: basemap tile fetch failed — #{e.message}"
    nil
  end

  private

  def parse_geometry
    return nil unless @activity.geojson_path.present?
    JSON.parse(@activity.geojson_path)
  end

  def flatten_coords(geometry)
    case geometry["type"]
    when "LineString"      then geometry["coordinates"]
    when "MultiLineString" then geometry["coordinates"].flatten(1)
    else []
    end
  end

  def linestrings(geometry)
    case geometry["type"]
    when "LineString"      then [ geometry["coordinates"] ]
    when "MultiLineString" then geometry["coordinates"]
    else []
    end
  end

  # Pick the highest zoom that still fits the bbox in the viewport tile budget.
  def auto_zoom(lon_range, lat_range)
    zoom_for_width  = Math.log2(WIDTH  * 360.0 / (lon_range * 256)).floor
    zoom_for_height = Math.log2(HEIGHT * 180.0 / (lat_range * 256)).floor
    [ zoom_for_width, zoom_for_height ].min.clamp(5, 16)
  end
end
