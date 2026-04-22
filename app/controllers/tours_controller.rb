class ToursController < ApplicationController
  before_action :authenticate!
  before_action :set_tour, only: [ :show, :edit, :update, :destroy, :remove_activity, :add_activities ]

  def index
    redirect_to activities_path
  end

  def show
    respond_to do |format|
      format.html

      format.geojson do
        geojson = @tour.geojson_path
        waypoints = @tour.activities.filter_map do |activity|
          start_coord, end_coord = activity.map_endpoints
          next unless start_coord
          { start: start_coord, end: end_coord }
        end
        render json: {
          type: "Feature",
          geometry: geojson ? JSON.parse(geojson) : nil,
          properties: { waypoints: waypoints },
        }
      end

      format.png do
        return head :not_found unless StaticMapService.available?
        cache_key = "tour_map_png/v1/#{@tour.id}/#{@tour.updated_at.to_i}"
        png = Rails.cache.fetch(cache_key, expires_in: 7.days) do
          StaticMapService.new(@tour).render
        end
        return head :not_found unless png
        send_data png, type: "image/png", disposition: "inline"
      end
    end
  end

  def new
    @tour = Tour.new
  end

  def create
    @tour = Tour.new(tour_params)
    @tour.user = Current.user
    @tour.activity_type = "Tour"

    if @tour.save
      assign_range_activities(@tour, params[:start_date], params[:end_date])
      @tour.recalculate_stats!
      redirect_to tour_path(@tour), notice: "Tour created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @tour.update(tour_params)
      @tour.recalculate_stats!
      redirect_to tour_path(@tour), notice: "Tour updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tour.activities.update_all(tour_id: nil)
    @tour.destroy
    redirect_to activities_path, notice: "Tour deleted."
  end

  def preview_activities
    @activities = activities_in_range(params[:start_date], params[:end_date])
    render partial: "preview_activities", locals: { activities: @activities }
  end

  def remove_activity
    @tour.activities.where(id: params[:activity_id]).update_all(tour_id: nil)
    @tour.recalculate_stats!
    redirect_to edit_tour_path(@tour)
  end

  def add_activities
    assign_range_activities(@tour, params[:start_date], params[:end_date])
    @tour.recalculate_stats!
    redirect_to edit_tour_path(@tour)
  end

  private

  def set_tour
    @tour = Current.user.activities.where(type: "Tour").find(params[:id])
  end

  def tour_params
    params.require(:tour).permit(:name, :description)
  end

  def activities_in_range(start_date, end_date)
    start_date = Date.parse(start_date.to_s) rescue nil
    end_date   = Date.parse(end_date.to_s) rescue nil
    return Activity.none unless start_date && end_date

    Current.user.activities
      .where(type: nil, tour_id: nil)
      .where(start_time: start_date.beginning_of_day..end_date.end_of_day)
      .chronologically
  end

  def assign_range_activities(tour, start_date, end_date)
    activities = activities_in_range(start_date, end_date)
    activities.update_all(tour_id: tour.id) if activities.any?
  end
end
