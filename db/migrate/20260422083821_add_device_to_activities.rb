class AddDeviceToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :device, :string
  end
end
