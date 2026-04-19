class SharesController < ApplicationController
  def show
    @record = Activity.find_by!(share_token: params[:token])
    @owner  = @record.user

    respond_to do |format|
      format.html

      format.geojson do
        record = Activity.find_by!(share_token: params[:token])
        geojson = record.geojson_path

        properties = if record.is_a?(Tour)
          waypoints = record.activities.filter_map do |activity|
            start_coord, end_coord = activity.map_endpoints
            next unless start_coord
            { start: start_coord, end: end_coord }
          end
          { waypoints: waypoints }
        else
          record = Activity.where(type: nil).with_geojson.find_by!(share_token: params[:token])
          geojson = record.geojson_path
          start_coord, end_coord = record.map_endpoints
          { start: start_coord, end: end_coord }
        end

        render json: { type: "Feature", geometry: geojson ? JSON.parse(geojson) : nil, properties: properties }
      end

      format.png do
        return head :not_found unless StaticMapService.available?
        cache_key = "share_map_png/v1/#{@record.id}/#{@record.updated_at.to_i}"
        png = Rails.cache.fetch(cache_key, expires_in: 7.days) do
          StaticMapService.new(@record).render
        end
        return head :not_found unless png
        send_data png, type: "image/png", disposition: "inline"
      end
    end
  end
end
