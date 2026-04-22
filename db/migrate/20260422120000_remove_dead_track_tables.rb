class RemoveDeadTrackTables < ActiveRecord::Migration[8.1]
  def up
    # activity_points was used by the old MVT heatmap pipeline — nothing writes to it anymore
    drop_table :activity_points

    # activities.track (4326 geography) was never populated by the import pipeline
    remove_column :activities, :track

    # Materialized view for MVT tile generation — superseded by activity_tiles
    execute "DROP MATERIALIZED VIEW IF EXISTS activity_segments_mvts"
  end

  def down
    execute <<~SQL
      CREATE MATERIALIZED VIEW activity_segments_mvts AS
        WITH zoom_levels AS (SELECT generate_series(0, 15) AS z)
        SELECT s.id, a.user_id, a.activity_type, a.name AS activity_name,
               a.start_time AS start_date, z.z AS zoom_level,
               CASE
                 WHEN z.z < 10 THEN ST_Simplify(ST_Transform(s.geom, 3857), 200)
                 WHEN z.z < 13 THEN ST_Simplify(ST_Transform(s.geom, 3857), 50)
                 ELSE ST_Transform(s.geom, 3857)
               END AS geom
        FROM activity_segments s
        JOIN activities a ON s.activity_id = a.id
        CROSS JOIN zoom_levels z
        WHERE s.geom IS NOT NULL AND NOT ST_IsEmpty(s.geom)
          AND ST_Length(ST_Transform(s.geom, 3857)) > CASE
            WHEN z.z <= 7 THEN 500 WHEN z.z <= 10 THEN 100 ELSE 0 END;
    SQL

    add_column :activities, :track,
      :geography, limit: { srid: 4326, type: "line_string", has_z: true, geographic: true }

    create_table :activity_points, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :activity_segment, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.geometry :geom, limit: { srid: 3857, type: "st_point" }, null: false
      t.index :geom, using: :gist
    end
  end
end
