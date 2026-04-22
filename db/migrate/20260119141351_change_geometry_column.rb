class ChangeGeometryColumn < ActiveRecord::Migration[8.1]
  def up
    # 1. Drop spatial index if it exists
    remove_index :activity_segments, :geom if index_exists?(:activity_segments, :geom)

    # 2. Reproject geometry to EPSG:4326
    execute <<~SQL
      ALTER TABLE activity_segments
      ALTER COLUMN geom
      TYPE geometry(LINESTRINGZ, 4326)
      USING ST_Transform(geom, 4326);
    SQL

    # 3. Recreate spatial index
    add_index :activity_segments, :geom, using: :gist
  end

  def down
    remove_index :activity_segments, :geom if index_exists?(:activity_segments, :geom)

    execute <<~SQL
      ALTER TABLE activity_segments
      ALTER COLUMN geom
      TYPE geometry(LINESTRINGZ, 3857)
      USING ST_Transform(geom, 3857);
    SQL

    add_index :activity_segments, :geom, using: :gist
  end
end
