# app/services/activity_heatmap_tile_service.rb
class ActivityHeatmapTileService
  TILE_SIZE = 4096

  # Grid size in meters per zoom level ranges
  GRID_METERS_BY_ZOOM = {
    0..7   => 100, # Was 200
    8..10  => 40,  # Was 80
    11..13 => 15,  # Was 30
    14..22 => 5    # Was 15 (Very fine detail for street level)
  }.freeze

  def initialize(tile)
    @tile = tile
  end

  def mvt
    result = ActiveRecord::Base.connection.exec_query(sql, "heatmap_mvt", @tile.deconstruct)
    raw_data = result.first["mvt"]

    raw_data ? ActivitySegmentsMvt.connection.unescape_bytea(raw_data) : nil
  end

  def sql
    <<~SQL
    WITH bounds AS (
      SELECT ST_TileEnvelope($1, $2, $3) AS geom
      ),
    snapped_points AS (
      SELECT
        -- This mathematically groups points into cells without creating real cell geometries
        ST_SnapToGrid(p.geom,
        CASE
          WHEN $1 < 8  THEN 60
          WHEN $1 < 11 THEN 30
          WHEN $1 < 14 THEN 10
          ELSE 2
      END
      ) AS grid_point,
      COUNT(*) AS weight
      FROM activity_points p, bounds b
      WHERE p.geom && b.geom  -- FAST: Uses Spatial Index to grab only points in this tile
      GROUP BY grid_point
      )
    SELECT ST_AsMVT(tile_data, 'heat') AS mvt
    FROM (
      SELECT
        ST_AsMVTGeom(s.grid_point, b.geom, 4096, 256, true) AS geom,
        s.weight
      FROM snapped_points s, bounds b
      ) AS tile_data;
    SQL
  end

  private

  def grid_size
    GRID_METERS_BY_ZOOM.each do |range, size|
      return size if range.include?(@z)
    end
    15
  end
end
