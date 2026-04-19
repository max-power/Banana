class ActivityStatisticsQuery
  # period is optional (used for grouped results like weeks or months)
  Statistic = Data.define(:time_range, :moving_time, :distance, :activities_count, :active_days, :period)

  def initialize(user, time_range)
    @user = user
    @time_range = time_range
  end

  def call(group_by: nil)
    query = base_query
    query = query.group(group_sql(group_by)).select(group_sql(group_by)) if group_by

    results = query.to_a

    # If we didn't group, we expect a single object; otherwise, an array
    group_by ? results.map { |r| map_record(r, group_by) } : map_record(results.first)
  end

  private

  def base_query
    @user.activities
         .where(type: nil, start_time: @time_range)
         .select(
           "SUM(moving_time) AS moving_time",
           "SUM(distance) AS distance",
           "COUNT(id) AS activities_count",
           "COUNT(DISTINCT start_time::DATE) AS active_days"
         )
  end

  def group_sql(interval)
    "DATE_TRUNC('#{interval}', start_time)"
  end

  def map_record(record, interval = nil)
    Statistic.new(
      time_range: @time_range,
      moving_time: record.moving_time.to_i,
      distance: record.distance.to_f,
      activities_count: record.activities_count.to_i,
      active_days: record.active_days.to_i,
      period: format_period(record, interval)
    )
  end

  def format_period(record, interval)
    return nil unless interval
    interval == 'month' ? Month.from(record.month) : Week.from(record.week)
  end
end

class YearActivityStatisticsQuery < ActivityStatisticsQuery
  def call
    super(group_by: 'month')
  end
end

class MonthActivityStatisticsQuery < ActivityStatisticsQuery
  def call
    super(group_by: 'week')
  end
end
