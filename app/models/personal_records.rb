class PersonalRecords
  # Returned for single-activity records
  ActivityRecord = Data.define(:activity, :formatted_value)

  # Returned for aggregate (day/week/month) records
  PeriodRecord = Data.define(:label, :formatted_distance, :formatted_elevation, :activity_count)

  # Returned for streak records
  StreakRecord = Data.define(:days, :start_date, :end_date)

  def initialize(user)
    @user = user
    @scope = user.activities.where(type: nil)
  end

  # ── Single-activity records ──────────────────────────────────────────────────

  def longest
    activity = @scope.where.not(distance: nil).order(distance: :desc).first
    return nil unless activity
    ActivityRecord.new(activity: activity, formatted_value: km(activity.distance))
  end

  def most_elevation
    activity = @scope.where.not(elevation_gain: nil).order(elevation_gain: :desc).first
    return nil unless activity
    ActivityRecord.new(activity: activity, formatted_value: "↑ #{activity.elevation_gain.round} m")
  end

  def longest_moving_time
    activity = @scope.where.not(moving_time: nil).order(moving_time: :desc).first
    return nil unless activity
    ActivityRecord.new(activity: activity, formatted_value: fmt_duration(activity.moving_time))
  end

  # Fastest average speed per activity type (exclude very short activities < 5 km)
  # Returns an array of ActivityRecord, one per type that has data.
  def fastest_by_type
    type_bests = @scope
      .where("distance >= 5000")
      .where.not(average_speed: nil)
      .select("DISTINCT ON (activity_type) *")
      .order("activity_type, average_speed DESC")

    type_bests.map do |a|
      fmt = if %w[running walking hiking].include?(a.activity_type.to_s)
        total_s = (1000.0 / a.average_speed).round
        "%d:%02d /km" % total_s.divmod(60)
      else
        "#{(a.average_speed * 3.6).round(1)} km/h"
      end
      ActivityRecord.new(activity: a, formatted_value: fmt)
    end
  end

  # ── Period bests ─────────────────────────────────────────────────────────────

  def best_day
    row = period_query("DATE(start_time AT TIME ZONE 'UTC')")
    return nil unless row
    PeriodRecord.new(
      label:               Date.parse(row["period"]).strftime("%b %-d, %Y"),
      formatted_distance:  km(row["total_distance"].to_f),
      formatted_elevation: "↑ #{row["total_elevation"].to_i} m",
      activity_count:      row["activity_count"].to_i
    )
  end

  def best_week
    row = period_query("DATE_TRUNC('week', start_time AT TIME ZONE 'UTC')")
    return nil unless row
    week_start = Date.parse(row["period"])
    PeriodRecord.new(
      label:               "#{week_start.strftime("%b %-d")} – #{(week_start + 6).strftime("%b %-d, %Y")}",
      formatted_distance:  km(row["total_distance"].to_f),
      formatted_elevation: "↑ #{row["total_elevation"].to_i} m",
      activity_count:      row["activity_count"].to_i
    )
  end

  def best_month
    row = period_query("DATE_TRUNC('month', start_time AT TIME ZONE 'UTC')")
    return nil unless row
    PeriodRecord.new(
      label:               Date.parse(row["period"]).strftime("%B %Y"),
      formatted_distance:  km(row["total_distance"].to_f),
      formatted_elevation: "↑ #{row["total_elevation"].to_i} m",
      activity_count:      row["activity_count"].to_i
    )
  end

  # ── Streaks ──────────────────────────────────────────────────────────────────

  def current_streak
    streak_ending_on(Date.today) || streak_ending_on(Date.yesterday) || StreakRecord.new(days: 0, start_date: nil, end_date: nil)
  end

  def longest_streak
    result = connection.exec_query(streak_sql, "longest_streak", [ @user.id ]).max_by { |r| r["days"].to_i }
    return nil unless result
    StreakRecord.new(
      days:       result["days"].to_i,
      start_date: Date.parse(result["start_date"]),
      end_date:   Date.parse(result["end_date"])
    )
  end

  private

  def period_query(truncation_expr)
    sql = <<~SQL
      SELECT #{truncation_expr}::text AS period,
             SUM(distance)       AS total_distance,
             SUM(elevation_gain) AS total_elevation,
             COUNT(*)            AS activity_count
      FROM activities
      WHERE user_id = $1
        AND type IS NULL
        AND start_time IS NOT NULL
        AND distance IS NOT NULL AND distance > 0
      GROUP BY #{truncation_expr}
      ORDER BY total_distance DESC
      LIMIT 1
    SQL
    connection.exec_query(sql, "period_best", [ @user.id ]).first
  end

  def streak_ending_on(date)
    result = streak_sql_ending(date)
    return nil unless result && result["days"].to_i > 0
    StreakRecord.new(
      days:       result["days"].to_i,
      start_date: Date.parse(result["start_date"]),
      end_date:   Date.parse(result["end_date"])
    )
  end

  def streak_sql_ending(date)
    sql = <<~SQL
      WITH active_dates AS (
        SELECT DISTINCT DATE(start_time AT TIME ZONE 'UTC') AS d
        FROM activities
        WHERE user_id = $1 AND type IS NULL AND start_time IS NOT NULL
      ),
      numbered AS (
        SELECT d, ROW_NUMBER() OVER (ORDER BY d DESC) AS rn
        FROM active_dates
        WHERE d <= $2
      ),
      grouped AS (
        SELECT d, (d + (rn || ' days')::interval)::date AS grp
        FROM numbered
      ),
      streak AS (
        SELECT grp, MIN(d) AS start_date, MAX(d) AS end_date, COUNT(*) AS days
        FROM grouped
        GROUP BY grp
        HAVING MAX(d) >= $2
      )
      SELECT * FROM streak LIMIT 1
    SQL
    connection.exec_query(sql, "current_streak", [ @user.id, date.to_s ]).first
  end

  def streak_sql
    <<~SQL
      WITH active_dates AS (
        SELECT DISTINCT DATE(start_time AT TIME ZONE 'UTC') AS d
        FROM activities
        WHERE user_id = $1 AND type IS NULL AND start_time IS NOT NULL
      ),
      numbered AS (
        SELECT d, ROW_NUMBER() OVER (ORDER BY d) AS rn FROM active_dates
      ),
      grouped AS (
        SELECT d, (d - (rn || ' days')::interval)::date AS grp FROM numbered
      )
      SELECT grp, MIN(d)::text AS start_date, MAX(d)::text AS end_date, COUNT(*) AS days
      FROM grouped
      GROUP BY grp
      ORDER BY days DESC
    SQL
  end

  def km(meters)
    "#{(meters.to_f / 1000).round(1)} km"
  end

  def fmt_duration(seconds)
    return "—" unless seconds&.positive?
    h, rem = seconds.divmod(3600)
    m, s   = rem.divmod(60)
    h > 0 ? "%d:%02d:%02d" % [h, m, s] : "%d:%02d" % [m, s]
  end

  def connection
    ActiveRecord::Base.connection
  end
end
