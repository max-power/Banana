class ToursController < ApplicationController
  before_action :authenticate!
  before_action :set_tour, only: [ :show, :edit, :update, :destroy ]

  def index
    redirect_to activities_path
  end

  def show
    respond_to do |format|
      format.html
      format.geojson { render json: @tour.geojson_path }
    end
  end

  def new
    @tour = Tour.new
    @available_activities = unassigned_activities
  end

  def create
    @tour = Tour.new(tour_params)
    @tour.user = Current.user
    @tour.activity_type = "Tour"

    if @tour.save
      assign_activities(@tour)
      @tour.recalculate_stats!
      redirect_to tour_path(@tour), notice: "Tour created."
    else
      @available_activities = unassigned_activities
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_activities = unassigned_activities(except: @tour)
  end

  def update
    if @tour.update(tour_params)
      @tour.activities.update_all(tour_id: nil)
      assign_activities(@tour)
      @tour.recalculate_stats!
      redirect_to tour_path(@tour), notice: "Tour updated."
    else
      @available_activities = unassigned_activities(except: @tour)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @tour.activities.update_all(tour_id: nil)
    @tour.destroy
    redirect_to activities_path, notice: "Tour deleted."
  end

  private

  def set_tour
    @tour = Current.user.activities.where(type: "Tour").find(params[:id])
  end

  def tour_params
    params.require(:tour).permit(:name, :description)
  end

  def unassigned_activities(except: nil)
    scope = Current.user.activities.where(type: nil, tour_id: nil).reverse_chronologically
    scope = scope.or(Current.user.activities.where(tour_id: except.id)) if except
    scope
  end

  def assign_activities(tour)
    ids = Array(params[:activity_ids]).reject(&:blank?)
    Current.user.activities.where(id: ids).update_all(tour_id: tour.id) if ids.any?
  end
end
