class AddZToSegments < ActiveRecord::Migration[8.1]
    def up
        execute <<-SQL
        ALTER TABLE activity_segments
        ALTER COLUMN geom TYPE geometry(LineStringZ, 3857)
        USING ST_Force3DZ(geom);
        SQL
    end

    def down
        execute <<-SQL
        ALTER TABLE activity_segments
        ALTER COLUMN geom TYPE geometry(LineString, 3857)
        USING ST_Force2D(geom);
        SQL
    end
end
