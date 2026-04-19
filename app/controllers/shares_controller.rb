class SharesController < ApplicationController
  def show
    @activity = Activity.where(type: nil).find_by!(share_token: params[:token])
    @owner = @activity.user

    respond_to do |format|
      format.html
      format.geojson do
        @activity = Activity.where(type: nil).with_geojson.find_by!(share_token: params[:token])
        render json: @activity.geojson_path
      end
    end
  end
end
