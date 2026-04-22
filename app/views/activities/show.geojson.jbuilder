json.type "Feature"
json.properties do
  json.id @activity.id
  json.name @activity.name
  json.activity_type @activity.activity_type
  json.distance @activity.distance
  json.moving_time @activity.moving_time
  json.elapsed_time @activity.elapsed_time
end
if @activity.is_a?(Tour)
  json.bbox @activity.bbox
  json.geometry @activity.track
else
  json.bbox RGeo::GeoJSON.encode(@activity.bbox)
  json.geometry RGeo::GeoJSON.encode(@activity.track)
end
