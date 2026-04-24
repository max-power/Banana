class AddElevationCorrectedToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :elevation_corrected, :boolean
  end
end
