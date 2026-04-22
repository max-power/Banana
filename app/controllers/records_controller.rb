class RecordsController < ApplicationController
  before_action :authenticate!

  def show
    response.set_header("Cache-Control", "no-store")
    @records = PersonalRecords.new(Current.user)
  end
end
