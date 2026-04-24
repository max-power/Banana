class CorrectElevationJob < ApplicationJob
  queue_as :default

  # Moving-average window for smoothing raw DEM elevations.
  # SRTM30 has ~30m resolution; a window of 20 points at typical GPS density
  # (~5m apart) smooths over ~100m, removing grid-cell staircase noise while
  # preserving genuine climbs.
  SMOOTH_WINDOW = 20


  def perform(activity_id)
    activity = Activity.where(type: nil).find_by(id: activity_id)
    return unless activity

    # 1. Extract coordinates per segment from PostGIS
    segments = fetch_segments(activity_id)
    return if segments.empty?

    # 2. Collect all [lon, lat] points in order
    all_points = segments.flat_map { |s| s[:coords] }

    # 3. Fetch corrected elevations from DEM service
    raw_elevations = OpenTopoDataService.elevations_for(all_points)

    # 4. Smooth per-segment and write back
    offset = 0
    segments.each do |seg|
      count     = seg[:coords].size
      seg_elevs = raw_elevations[offset, count]
      offset   += count

      smoothed = smooth(seg_elevs)
      update_segment_geom(seg[:id], seg[:coords], smoothed)
    end

    # 5. Rebuild the denormalized track_3857 on the activity
    rebuild_track_3857(activity_id)

    # 6. Recalculate elevation_gain / elevation_loss from updated geom
    gain, loss = recalculate_elevation(activity_id)

    activity.update_columns(
      elevation_gain:      gain,
      elevation_loss:      loss,
      elevation_corrected: true,
    )

  rescue OpenTopoDataService::Error => e
    Rails.logger.error "CorrectElevationJob failed for activity #{activity_id}: #{e.message}"
    raise
  end

  private

  # Simple centred moving average, computed per segment so gaps don't bleed.
  def smooth(elevations, window: SMOOTH_WINDOW)
    return elevations if elevations.size < 3

    half = window / 2
    elevations.each_with_index.map do |_, i|
      lo     = [i - half, 0].max
      hi     = [i + half, elevations.size - 1].min
      values = elevations[lo..hi].compact
      values.empty? ? elevations[i] : values.sum.to_f / values.size
    end
  end

  def fetch_segments(activity_id)
    conn.exec_query(<<~SQL, "elev_seg_coords", [activity_id])
      SELECT id, ST_AsGeoJSON(geom) AS geojson
      FROM   activity_segments
      WHERE  activity_id = $1
      ORDER  BY segment_index
    SQL
    .map do |row|
      geo    = JSON.parse(row["geojson"])
      coords = geo["coordinates"].map { |c| [c[0].to_f, c[1].to_f] }  # [lon, lat]
      { id: row["id"], coords: coords }
    end
  end

  # geom_3857 is a generated column — Postgres recomputes it automatically.
  def update_segment_geom(segment_id, coords, elevations)
    pts = coords.zip(elevations).map do |(lon, lat), elev|
      "#{lon} #{lat} #{elev || 0}"
    end
    wkt = "LINESTRING Z (#{pts.join(', ')})"

    conn.exec_query(<<~SQL, "update_seg_elev", [wkt, segment_id])
      UPDATE activity_segments
      SET    geom       = ST_SetSRID(ST_GeomFromText($1), 4326),
             updated_at = NOW()
      WHERE  id = $2
    SQL
  end

  def rebuild_track_3857(activity_id)
    conn.exec_query(<<~SQL, "rebuild_track_3857", [activity_id])
      UPDATE activities
      SET    track_3857 = (
               SELECT ST_Collect(geom_3857 ORDER BY segment_index)
               FROM   activity_segments WHERE activity_id = $1
             )
      WHERE  id = $1
    SQL
  end

  def recalculate_elevation(activity_id)
    row = conn.exec_query(<<~SQL, "recalc_elev", [activity_id]).first
      WITH pts AS (
        SELECT ST_Z(dp.geom) AS z
        FROM   activity_segments s,
               LATERAL ST_DumpPoints(s.geom) dp
        WHERE  s.activity_id = $1
        ORDER  BY s.segment_index, (dp.path)[1]
      ),
      diffs AS (
        SELECT z - LAG(z) OVER () AS diff FROM pts
      )
      SELECT
        COALESCE(SUM(CASE WHEN diff > 0 THEN diff ELSE 0 END), 0)::int AS gain,
        COALESCE(SUM(CASE WHEN diff < 0 THEN ABS(diff) ELSE 0 END), 0)::int AS loss
      FROM diffs
    SQL
    [row["gain"], row["loss"]]
  end

  def conn
    ActiveRecord::Base.connection
  end
end
