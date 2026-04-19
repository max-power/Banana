class CreateActivityPoints < ActiveRecord::Migration[8.1]
    disable_ddl_transaction!

    def up


        execute <<~SQL
        CREATE TABLE activity_points (
            id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
            activity_segment_id uuid NOT NULL,
            geom geometry(Point, 3857) NOT NULL
        );
        SQL

        execute <<~SQL
        CREATE INDEX CONCURRENTLY idx_activity_points_geom
        ON activity_points
        USING GIST (geom);
        SQL

        execute <<~SQL
        CREATE INDEX CONCURRENTLY idx_activity_points_activity_segment_id
        ON activity_points (activity_segment_id);
        SQL

        execute <<~SQL
        ALTER TABLE activity_points
        ADD CONSTRAINT fk_activity_points_segments
        FOREIGN KEY (activity_segment_id)
        REFERENCES activity_segments(id)
        ON DELETE CASCADE;
        SQL
    end

    def down
        execute <<~SQL
        DROP TABLE IF EXISTS activity_points;
        SQL
    end
end
