class Calendar::YearsController < ApplicationController
  before_action :authenticate!
  Statistic = Data.define(:time_range, :month, :moving_time, :distance, :elevation_gain, :activities_count, :active_days)

  def show
    # all years with activities
    # Activity.distinct.pluck(Arel.sql("EXTRACT(YEAR FROM created_at)"))

    @year = Tempora::Year.new(params[:year])
    #@activities = Current.user.activities.within_time_range(@year.range)

    @statistics = statistics
    @daily_statistics = daily_distances
  end

  private

  def daily_distances
    daily_data = Current.user.activities.select(
      "start_time::DATE AS day,
      SUM(distance) AS distance,
      COUNT(id) AS activities_count"
    ).where(
      type: nil
    ).where(
      start_time: @year.range
    ).group(
      "start_time::DATE"
    ).order(
      "start_time::DATE"
    ).index_by { |result| result.day }

    @daily_distances = @year.range.map do |date|
      day_data = daily_data[date]
      {
        date: date,
        distance: day_data ? day_data.distance.to_f : 0.0,
        activities_count: day_data ? day_data.activities_count.to_i : 0
      }
    end
  end

  def statistics
    Current.user.activities.select(
      "SUM(moving_time) AS moving_time,
      SUM(distance) AS distance,
      SUM(elevation_gain) AS elevation_gain,
      COUNT(id) AS activities_count,
      COUNT(DISTINCT start_time::DATE) AS active_days,
      DATE_TRUNC('month', start_time) AS month"
    ).where(
      type: nil
    ).where(
      start_time: @year.range
    ).group(
      "DATE_TRUNC('month', start_time)"
    ).map do |result|
      Statistic.new(
        time_range: @year.range,
        month: Tempora::Month.from(result.month),
        moving_time: result.moving_time.to_i,
        distance: result.distance.to_f,
        elevation_gain: result.elevation_gain.to_i,
        activities_count: result.activities_count.to_i,
        active_days: result.active_days.to_i
      )
    end
  end
end
