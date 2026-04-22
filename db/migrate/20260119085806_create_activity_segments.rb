class CreateActivitySegments < ActiveRecord::Migration[8.1]
    def change
        create_table :activity_segments, id: :uuid do |t|
            t.references :activity, null: false, foreign_key: true, type: :uuid

            t.integer :segment_index, null: false

            t.datetime :start_time
            t.datetime :end_time

            t.integer :moving_time_s
            t.float :distance_m

            # PostGIS geometry column (EPSG:3857)
            t.geometry :geom, geographic: false, srid: 3857, type: :line_string, null: false, has_z: true

            t.timestamps
        end

        # ----------------------------
        # Critical indexes (DO NOT SKIP)
        # ----------------------------

        # Spatial index for tiles & heatmaps
        add_index :activity_segments, :geom, using: :gist


        # Segment ordering & playback
        add_index :activity_segments, [:activity_id, :segment_index], unique: true, name: "idx_activity_segments_activity_order"

        # Optional but very useful for time-based queries
        add_index :activity_segments, [:start_time, :end_time], name: "idx_activity_segments_time_range"


        execute <<~SQL
        ALTER TABLE activity_segments
        ADD CONSTRAINT activity_segments_min_points
        CHECK (ST_NPoints(geom) >= 2);
        SQL
    end
end
