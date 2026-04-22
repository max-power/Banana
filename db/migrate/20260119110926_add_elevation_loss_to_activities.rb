class AddElevationLossToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :elevation_loss, :integer
  end
end
