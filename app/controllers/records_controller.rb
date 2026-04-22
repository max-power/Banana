class RecordsController < ApplicationController
  before_action :authenticate!

  def show
    @records = PersonalRecords.new(Current.user)
  end
end
