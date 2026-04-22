class AddDensityPointGeomToActivitySegments < ActiveRecord::Migration[8.1]
    disable_ddl_transaction!

    def up
        execute <<~SQL
        ALTER TABLE activity_segments
        ADD COLUMN geom_3857 geometry(LineStringZ, 3857)
        GENERATED ALWAYS AS (
        ST_Transform(geom, 3857)
        ) STORED;
        SQL

        execute <<~SQL
        CREATE INDEX CONCURRENTLY idx_activity_segments_geom_3857
        ON activity_segments
        USING GIST (geom_3857);
        SQL
    end

    def down
        execute <<~SQL
        DROP INDEX CONCURRENTLY IF EXISTS idx_activity_segments_geom_3857;
        SQL

        execute <<~SQL
        ALTER TABLE activity_segments
        DROP COLUMN IF EXISTS geom_3857;
        SQL
    end
end
