class PopulateTrack3857FromSegments < ActiveRecord::Migration[8.1]
  def up
    # Widen column to accept MultiLineString (activities with multiple segments)
    execute "ALTER TABLE activities ALTER COLUMN track_3857 TYPE geometry(GeometryZ, 3857) USING track_3857::geometry(GeometryZ, 3857)"
    remove_index :activities, name: "activities_track_3857_gix", if_exists: true
    remove_index :activities, name: "idx_activities_track_3857", if_exists: true

    execute <<~SQL
      UPDATE activities
      SET track_3857 = (
        SELECT ST_Collect(geom_3857 ORDER BY segment_index)
        FROM activity_segments
        WHERE activity_id = activities.id
      )
      WHERE EXISTS (
        SELECT 1 FROM activity_segments WHERE activity_id = activities.id
      )
    SQL

    add_index :activities, :track_3857, using: :gist, name: "idx_activities_track_3857"
  end

  def down
    remove_index :activities, name: "idx_activities_track_3857", if_exists: true
    execute "ALTER TABLE activities ALTER COLUMN track_3857 TYPE geometry(LineString, 3857) USING NULL"
    add_index :activities, :track_3857, using: :gist, name: "idx_activities_track_3857"
  end
end
