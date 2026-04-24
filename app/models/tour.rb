class Tour < Activity
  has_many :tour_memberships, foreign_key: :tour_id, dependent: :destroy
  has_many :activities, -> { where(type: nil).order(:start_time) }, through: :tour_memberships

  def display_type
    activity_type&.humanize || "Tour"
  end

  def days
    return 0 unless start_time && end_time
    (end_time.to_date - start_time.to_date).to_i + 1
  end

  def recalculate_stats!
    row = self.class.connection.exec_query(<<~SQL, "tour_stats", [ id ]).first
      SELECT
        COALESCE(SUM(a.distance), 0)       AS distance,
        COALESCE(SUM(a.elevation_gain), 0) AS elevation_gain,
        COALESCE(SUM(a.elevation_loss), 0) AS elevation_loss,
        COALESCE(SUM(a.moving_time), 0)    AS moving_time,
        COALESCE(SUM(a.elapsed_time), 0)   AS elapsed_time,
        MIN(a.start_time)                  AS start_time,
        MAX(a.end_time)                    AS end_time
      FROM activities a
      INNER JOIN tour_memberships tm ON tm.activity_id = a.id
      WHERE tm.tour_id = $1 AND (a.type IS NULL OR a.type = '')
    SQL
    update_columns(
      distance:       row["distance"].to_f,
      elevation_gain: row["elevation_gain"].to_i,
      elevation_loss: row["elevation_loss"].to_i,
      moving_time:    row["moving_time"].to_i,
      elapsed_time:   row["elapsed_time"].to_i,
      start_time:     row["start_time"],
      end_time:       row["end_time"],
    )
  end

  def map_geojson
    return nil if activities.empty?

    self.class.connection.exec_query(<<~SQL, "tour_map_geojson", [ id ]).first&.dig("geojson")
      SELECT ST_AsGeoJSON(
        ST_Simplify(
          ST_Collect(s.geom_3857 ORDER BY a.start_time, s.segment_index),
          50
        )
      ) AS geojson
      FROM activity_segments s
      INNER JOIN activities a ON a.id = s.activity_id
      INNER JOIN tour_memberships tm ON tm.activity_id = a.id
      WHERE tm.tour_id = $1
    SQL
  end

  def geojson_path
    activity_ids = activities.pluck(:id)
    return nil if activity_ids.empty?

    quoted = activity_ids.map { |id| ActiveRecord::Base.connection.quote(id) }.join(",")
    result = ActiveRecord::Base.connection.execute(<<~SQL)
      SELECT ST_AsGeoJSON(
        ST_Simplify(
          ST_Collect(s.geom ORDER BY a.start_time, s.segment_index),
          0.0001
        )
      ) AS geojson_path
      FROM activity_segments s
      JOIN activities a ON a.id = s.activity_id
      WHERE s.activity_id IN (#{quoted})
    SQL
    result.first&.dig("geojson_path")
  end
end
