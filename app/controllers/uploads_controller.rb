class UploadsController < ApplicationController
  before_action :authenticate!

  # Renders the upload page. All upload logic is handled client-side:
  # files go via ActiveStorage DirectUpload, then POST /activities creates
  # the activity record. This action just serves the view.
  def show
  end
end
