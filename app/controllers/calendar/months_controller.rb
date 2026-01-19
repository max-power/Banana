class Calendar::MonthsController < ApplicationController
    Statistic = Data.define(:week, :time_range, :moving_time, :distance, :activities_count, :active_days)

    def show
        @year  = Tempora::Year.new(params[:year])
        @month = Tempora::Month.new(params[:year], params[:month])
        #range = Date.new(@year, @month).all_month
        @activities = Current.user.activities.within_time_range(@month.range)
        @statistics = statistics
    end

    private

    def statistics
        Current.user.activities.select(
            "SUM(moving_time) AS moving_time,
            SUM(distance) AS distance,
            COUNT(id) AS activities_count,
            COUNT(DISTINCT start_time::DATE) AS active_days,
            DATE_TRUNC('week', start_time) AS week"
        ).where(
            type: nil
        ).where(
            start_time: @month.range
        ).group(
            "DATE_TRUNC('week', start_time)"
        ).map do |result|
            Statistic.new(
                time_range: @month.range,
                week: Tempora::Week.from(result.week),
                moving_time: result.moving_time.to_i,
                distance: result.distance.to_f,
                activities_count: result.activities_count.to_i,
                active_days: result.active_days.to_i
            )
        end
    end
end
