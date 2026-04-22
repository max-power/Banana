class PersonalRecords
  # Returned for single-activity records
  ActivityRecord = Data.define(:activity, :formatted_value)

  # Returned for aggregate (day/week/month) records
  PeriodRecord = Data.define(:label, :formatted_distance, :formatted_elevation, :activity_count)

  # Returned for streak records
  StreakRecord = Data.define(:days, :start_date, :end_date)

  def initialize(user)
    @user = user
    @scope = user.activities.where(type: nil, duplicate_of_id: nil)
  end

  # ── Single-activity records (top 3) ─────────────────────────────────────────

  def longest
    @scope.where.not(distance: nil).order(distance: :desc).limit(3).map do |a|
      ActivityRecord.new(activity: a, formatted_value: km(a.distance))
    end
  end

  def most_elevation
    @scope.where.not(elevation_gain: nil).order(elevation_gain: :desc).limit(3).map do |a|
      ActivityRecord.new(activity: a, formatted_value: "↑ #{a.elevation_gain.round} m")
    end
  end

  def longest_moving_time
    @scope.where.not(moving_time: nil).order(moving_time: :desc).limit(3).map do |a|
      ActivityRecord.new(activity: a, formatted_value: fmt_duration(a.moving_time))
    end
  end

  # Best per activity type — one winner per type (top 3 types by count of activities)
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

  # ── Period bests (top 3) ─────────────────────────────────────────────────────

  def best_days
    period_records("DATE(start_time AT TIME ZONE 'UTC')") do |row|
      Date.parse(row["period"]).strftime("%b %-d, %Y")
    end
  end

  def best_weeks
    period_records("DATE_TRUNC('week', start_time AT TIME ZONE 'UTC')") do |row|
      week_start = Date.parse(row["period"])
      "#{week_start.strftime("%b %-d")} – #{(week_start + 6).strftime("%b %-d, %Y")}"
    end
  end

  def best_months
    period_records("DATE_TRUNC('month', start_time AT TIME ZONE 'UTC')") do |row|
      Date.parse(row["period"]).strftime("%B %Y")
    end
  end

  # ── Streaks ──────────────────────────────────────────────────────────────────

  def current_streak
    streak_ending_on(Date.today) || streak_ending_on(Date.yesterday) ||
      StreakRecord.new(days: 0, start_date: nil, end_date: nil)
  end

  def top_streaks
    connection.exec_query(streak_sql, "top_streaks", [ @user.id ])
              .first(3)
              .map do |row|
      StreakRecord.new(
        days:       row["days"].to_i,
        start_date: Date.parse(row["start_date"]),
        end_date:   Date.parse(row["end_date"])
      )
    end
  end

  private

  def period_records(truncation_expr, &label_formatter)
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
      LIMIT 3
    SQL
    connection.exec_query(sql, "period_best", [ @user.id ]).map do |row|
      PeriodRecord.new(
        label:               label_formatter.call(row),
        formatted_distance:  km(row["total_distance"].to_f),
        formatted_elevation: "↑ #{row["total_elevation"].to_i} m",
        activity_count:      row["activity_count"].to_i
      )
    end
  end

  def streak_ending_on(date)
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
    result = connection.exec_query(sql, "current_streak", [ @user.id, date.to_s ]).first
    return nil unless result && result["days"].to_i > 0
    StreakRecord.new(
      days:       result["days"].to_i,
      start_date: Date.parse(result["start_date"]),
      end_date:   Date.parse(result["end_date"])
    )
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
