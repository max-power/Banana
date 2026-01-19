Mime::Type.register "application/geo+json", :geojson
Mime::Type.register "application/x-protobuf", :mvt
Mime::Type.register "application/gpx+xml", :gpx, %w(text/xml application/xml)
Mime::Type.register "image/svg+xml", :svg unless Mime[:svg]
