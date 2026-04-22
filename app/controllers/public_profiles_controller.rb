class PublicProfilesController < ApplicationController
  def show
    @profile_user = User.find(params[:id])

    unless @profile_user.public_profile?
      render plain: "This profile is private.", status: :not_found and return
    end

    @activities = @profile_user.activities
      .where(type: nil)
      .reverse_chronologically
      .with_geojson
  end
end
