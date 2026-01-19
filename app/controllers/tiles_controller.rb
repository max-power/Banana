class TilesController < ApplicationController
    def show
        tile = Tile.new *params.values_at(:z, :x, :y).map(&:to_i)

        respond_to do |format|
            format.mvt { mvt_tile(tile) }
            format.png { raster_tile(tile) }
        end
    end

    private

    def raw_connection
        conn = ActiveRecord::Base.connection.raw_connection
        conn.type_map_for_results = PG::BasicTypeMapForResults.new(conn)
        conn
    end

    def mvt_tile(tile)
        cache_key = "#{Current.user.id}/#{tile.cache_key}"
        #fetched_tile = Rails.cache.fetch(cache_key, expires_in: 24.hours) do
            #fetched_tile = mvt_tile_query(tile)
            fetched_tile = fetch_tile_data(tile)
        #end
        if fetched_tile.present?
            send_data fetched_tile, type: 'application/x-protobuf', disposition: 'inline'
        else
            head :no_content
        end
    end

    def fetch_tile_data(tile)
        #return ActivityMvt.as_vector_tile(tile)
        query = <<~SQL
          SELECT ST_AsMVT(tile, 'activities')
          FROM (
            SELECT id, ST_AsMVTGeom(geom, ST_TileEnvelope($1, $2, $3)) AS mvt_geom
            FROM activity_mvts
            WHERE zoom_level = $1 AND geom && ST_TileEnvelope($1, $2, $3)
          ) AS tile
        SQL

        result = ActivityMvt.connection.exec_query(
          query,
          "MVT Tile Fetch",
          [tile.z, tile.x, tile.y]
        )

        raw_data = result.rows.first&.first

        raw_data ? ActivityMvt.connection.unescape_bytea(raw_data) : nil


    end

    def mvt_tile_query(tile)

        # query = <<-SQL
        #     WITH tile AS (
        #     SELECT
        #     ST_AsMVTGeom(
        #     --ST_Simplify(track::geometry, 0.001)
        #     --            ST_LineMerge(ST_CollectionExtract(ST_Transform(track::geometry, 3857), 2)),  -- Force LineString
        #     ST_Transform(track::geometry, 3857),  -- Convert track to Web Mercator
        #     ST_TileEnvelope($1, $2, $3),  -- Tile bounding box in Web Mercator
        #     4096, 512, true
        #     ) AS geom

        #     FROM
        #     activities
        #     WHERE
        #     ST_Intersects(
        #     ST_Transform(track::geometry, 3857), -- Ensure track is in Web Mercator
        #     ST_TileEnvelope($1, $2, $3) -- Tile bbox in Web Mercator
        #     )
        #     )
        #     SELECT ST_AsMVT(tile, 'default') as mvt_tile FROM tile WHERE geom IS NOT NULL;
        # SQL

        query = <<-SQL
        WITH tile AS (
          SELECT
            ST_AsMVTGeom(
              -- Simplify based on zoom level ($1 = z)
              CASE
                WHEN $1 < 10 THEN ST_Simplify(track_3857, 200)  -- very low zoom
                WHEN $1 < 13 THEN ST_Simplify(track_3857, 50)   -- medium zoom
                ELSE track_3857                                  -- high zoom, full detail
              END,
              ST_TileEnvelope($1, $2, $3),
              4096,
              256,
              true
            ) AS geom
          FROM activities
          -- Use the bounding box operator && for index-assisted filtering
          WHERE track_3857 && ST_TileEnvelope($1, $2, $3)
        )
        SELECT ST_AsMVT(tile, 'default') AS mvt_tile
        FROM tile
        WHERE geom IS NOT NULL;
        SQL

        raw_connection.exec_params(query, tile.deconstruct).getvalue(0,0)
    end

    def raster_tile(tile)

        query = <<-SQL
        WITH tile AS (
          SELECT
            ST_AsRaster(
              -- Simplify based on zoom level ($1 = z)
              CASE
                WHEN $1 < 10 THEN ST_Simplify(track_3857, 200)  -- very low zoom
                WHEN $1 < 13 THEN ST_Simplify(track_3857, 50)   -- medium zoom
                ELSE track_3857                                  -- high zoom, full detail
              END,
              ST_TileEnvelope($1, $2, $3),
              '8BUI',
              255, 0, 0
            ) AS rast
          FROM activities
          -- Use the bounding box operator && for index-assisted filtering
          WHERE track_3857 && ST_TileEnvelope($1, $2, $3)
        )
        SELECT ST_AsPNG(rast) AS png_tile FROM tile
        WHERE rast IS NOT NULL;
        SQL

        result = ActivityMvt.connection.exec_query(
          query,
          "PNG Tile Fetch",
          [tile.z, tile.x, tile.y]
        )
        raw_data = result.rows.first&.first


           # WITH tile AS (
           #   SELECT ST_AsRaster(
           #     ST_Union(ST_Transform(track::geometry, 3857)),
           #     ST_TileEnvelope($1, $2, $3),
           #     '8BUI', -- Pixel depth (8-bit unsigned integer)
           #     255, 0, 0  -- RGB color (red tracks)
           #   ) AS rast
           #   FROM activities
           # )
           # SELECT ST_AsPNG(rast) FROM tile;
           # SQL
           send_data raw_data, type: 'image/png', disposition: 'inline'
    end
end
