class ActivitySegmentsMvt < ApplicationRecord
  self.primary_key = :id

  def self.refresh(concurrently: false)
    Scenic.database.refresh_materialized_view(table_name, concurrently: concurrently, cascade: false)
  end

  def self.populated?
    Scenic.database.populated?(table_name)
  end

  def self.as_vector_tile(tile)
    # Using bind parameters with select_value
    # $1 = z, $2 = x, $3 = y
    sql = <<~SQL
    SELECT ST_AsMVT(tile, 'activities')
    FROM (
      SELECT
        id,
        ST_AsMVTGeom(geom, ST_TileEnvelope($1, $2, $3)) AS mvt_geom
      FROM activity_segments_mvts
      WHERE zoom_level = $1
      AND geom && ST_TileEnvelope($1, $2, $3)
      ) AS tile
    SQL

    # We use bind parameters for safety and performance
    binds = [
      ActiveRecord::Relation::QueryAttribute.new("z", tile.z, ActiveRecord::Type::Integer.new),
      ActiveRecord::Relation::QueryAttribute.new("x", tile.x, ActiveRecord::Type::Integer.new),
      ActiveRecord::Relation::QueryAttribute.new("y", tile.y, ActiveRecord::Type::Integer.new)
    ]

    result = connection.select_value(sql, "MVT Tile Fetch", binds)

    # Ensure binary format
    result ? connection.unescape_bytea(result) : nil
  end

  def readonly?
    true
  end
end
