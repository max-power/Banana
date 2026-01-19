class ActivitiesController < ApplicationController
    def index
        @activities = Current.user.activities.reverse_chronologically.limit(10)
    end

    def show

        respond_to do |format|
            # Renders show.html.erb
            format.html do
                @activity = Current.user.activities.find(params.expect(:id))
            end

            format.geojson do
                # return unless stale?(@activity)
                # Use the scope to fetch processed GeoJSON
                @activity = Current.user.activities.with_geojson(tolerance_param).find(params.expect(:id))
                render json: @activity.geojson_path
            end

            #       format.svg do
            #         # If the route hasn't changed since the user last requested it,
            #         # stop here and send a 304 Not Modified.
            #         return unless stale?(@route)

            #         @route = Route.with_svg_path.find(params[:id])
            #         render :show, type: 'image/svg+xml'
            #       end

            # format.gpx do
            #     send_data @activity.file.download, type: Mime[:gpx]
            # end
        end
    end

    def new

    end

    def edit

    end

    def create
        @activity = Current.user.activities.new(activity_params)

        # Attach the blob using the signed_id from the frontend
        if params[:activity][:file].present?
            @activity.file.attach(params[:activity][:file])
        end

        if @activity.save
            # Trigger your analyzer here!
            #GpxAnalysisJob.perform_later(@activity.id)
            render json: { id: @activity.id, name: @activity.name }, status: :created
        else
            render json: @activity.errors, status: :unprocessable_entity
        end
    end

    def update

    end

    def destroy

    end

    private

    def activity_params
        params.require(:activity).permit(:name, :description, :file)
    end

    def tolerance_param
      tolerances = {
         "low"    => 0.001,  # Very simplified (fastest)
         "medium" => 0.0001, # Good balance
         "high"   => 0.00001 # High precision
      }
      tolerances.fetch(params[:detail]) { tolerances["medium"] }
    end
end
