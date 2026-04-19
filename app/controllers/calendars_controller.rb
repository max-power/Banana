class CalendarsController < ApplicationController
  def show
    @year  = params[:year]
    @month = params[:month]

    @activities = Current.user.activities.within_time_range(@month.range)
  end
end
