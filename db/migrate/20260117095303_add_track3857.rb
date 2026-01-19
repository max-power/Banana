class AddTrack3857 < ActiveRecord::Migration[8.1]
  def up
    add_column :activities, :track_3857, :geometry, geographic: false, srid: 3857, type: 'LineString', has_z: true

    execute <<~SQL
      UPDATE activities
      SET track_3857 = ST_Transform(track::geometry, 3857)
      WHERE track IS NOT NULL;
    SQL

    execute <<~SQL
      CREATE INDEX activities_track_3857_gix
      ON activities
      USING GIST (track_3857);
    SQL
  end

  def down
    execute "DROP INDEX IF EXISTS activities_track_3857_gix"
    remove_column :activities, :track_3857
  end
end
