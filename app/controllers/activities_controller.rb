class ActivitiesController < ApplicationController
  before_action :authenticate!, except: [:show]

  def index
    scope = Current.user.activities.with_map_geojson
    scope = scope.matching(params[:q]) if params[:q].present?
    scope = scope.where(tour_id: nil) if params[:q].blank?
    scope = scope.where(activity_type: params[:type]) if params[:type].present?
    if params[:year].present?
      scope = scope.where(start_time: Date.new(params[:year].to_i).beginning_of_year..Date.new(params[:year].to_i).end_of_year)
    end
    @years = Current.user.activities.where(type: nil).where.not(start_time: nil)
                    .pluck(Arel.sql("DISTINCT EXTRACT(YEAR FROM start_time)::int")).sort.reverse
    scope = case params[:sort]
            when "date_asc"       then scope.chronologically
            when "distance_desc"  then scope.order(distance: :desc, id: :desc)
            when "elevation_desc" then scope.order(elevation_gain: :desc, id: :desc)
            when "name_asc"       then scope.order(Arel.sql("LOWER(name) ASC NULLS LAST"))
            else                       scope.reverse_chronologically
            end
    @pagy, @activities = pagy(:offset, scope, limit: 30)
  end

  def show
    respond_to do |format|
      format.html do
        @activity = find_viewable_activity
        render plain: "Activity not found.", status: :not_found unless @activity
        @is_owner = authenticated? && @activity&.user_id == Current.user&.id
      end

      format.geojson do
        @activity = find_viewable_activity(with_geojson: true)
        if @activity
          start_coord, end_coord = @activity.map_endpoints
          render json: {
            type: "Feature",
            geometry: @activity.geojson_path ? JSON.parse(@activity.geojson_path) : nil,
            properties: { start: start_coord, end: end_coord },
          }
        else
          head :not_found
        end
      end

      format.png do
        return head :not_found unless StaticMapService.available?
        @activity = find_viewable_activity(with_geojson: true)
        return head :not_found unless @activity

        cache_key = "activity_map_png/v6/#{@activity.id}/#{@activity.updated_at.to_i}"
        png = Rails.cache.fetch(cache_key, expires_in: 7.days) do
          StaticMapService.new(@activity).render
        end

        return head :not_found unless png
        send_data png, type: "image/png", disposition: "inline"
      end
    end
  end

  def new
  end

  def export_original
    @activity = Current.user.activities.find(params.expect(:id))
    return head :not_found unless @activity.file.attached?
    redirect_to rails_blob_url(@activity.file, disposition: "attachment"), allow_other_host: true
  end

  def export_gpx
    @activity = Current.user.activities.find(params.expect(:id))
    send_data GPXExporter.new(@activity).to_gpx,
              filename: "#{slug(@activity)}.gpx",
              content_type: "application/gpx+xml", disposition: "attachment"
  end

  def export_geojson
    @activity = Current.user.activities.with_geojson(0).find(params.expect(:id))
    feature = {
      type: "Feature",
      geometry: @activity.geojson_path ? JSON.parse(@activity.geojson_path) : nil,
      properties: {
        name:           @activity.name,
        activity_type:  @activity.activity_type,
        start_time:     @activity.start_time,
        distance:       @activity.distance,
        moving_time:    @activity.moving_time,
        elevation_gain: @activity.elevation_gain,
        elevation_loss: @activity.elevation_loss,
      }.compact,
    }
    send_data JSON.pretty_generate(feature),
              filename: "#{slug(@activity)}.geojson",
              content_type: "application/geo+json", disposition: "attachment"
  end

  def edit
    @activity = Current.user.activities.find(params.expect(:id))
  end

  def create
    @activity = Current.user.activities.new(activity_params)
    duplicate = nil

    if params[:activity][:file].present?
      @activity.file.attach(params[:activity][:file])
      blob = @activity.file.blob
      blob.analyze unless blob.analyzed?
      duplicate = detect_duplicate_from_blob(blob)
    end

    if @activity.save
      @activity.touch if @activity.file.attached?
      render json: {
        id: @activity.id,
        name: @activity.name,
        duplicate_of: duplicate && { id: duplicate.id, name: duplicate.name.presence || "Untitled" },
      }, status: :created
    else
      render json: @activity.errors, status: :unprocessable_entity
    end
  end

  def update
    @activity = Current.user.activities.find(params.expect(:id))
    if @activity.update(activity_params)
      redirect_to @activity
    else
      render :edit
    end
  end

  def destroy
    @activity = Current.user.activities.find(params.expect(:id))
    if @activity.destroy
      redirect_to activities_path, notice: "Activity deleted."
    else
      redirect_to activity_path(@activity), alert: "Could not delete activity: #{@activity.errors.full_messages.to_sentence}"
    end
  end

  private

  def find_viewable_activity(with_geojson: false)
    scope = Activity.where(type: nil)
    scope = scope.with_geojson(tolerance_param) if with_geojson
    activity = scope.find_by(id: params[:id])
    return nil unless activity
    return activity if authenticated? && activity.user_id == Current.user.id
    return activity if activity.user.public_profile?
    nil
  end

  def detect_duplicate_from_blob(blob)
    return unless blob&.filename.extension.casecmp?("gpx")

    meta = GPX::Activity.new(blob.download).metadata
    start_time = Time.at(meta[:time_start]) if meta[:time_start]
    distance   = meta[:distance_m]
    return unless start_time && distance&.positive?

    Current.user.activities
      .where.not(id: @activity.id)
      .where(start_time: (start_time - 2.minutes)..(start_time + 2.minutes))
      .where(distance: (distance * 0.98)..(distance * 1.02))
      .first
  rescue => e
    Rails.logger.warn "Duplicate check failed: #{e.message}"
    nil
  end

  def slug(activity)
    activity.name&.parameterize.presence || activity.id
  end

  def activity_params
    params.require(:activity).permit(:name, :description, :activity_type, :file)
  end

  def tolerance_param
    tolerances = { "low" => 0.001, "medium" => 0.0001, "high" => 0.00001 }
    tolerances.fetch(params[:detail]) { tolerances["medium"] }
  end
end
