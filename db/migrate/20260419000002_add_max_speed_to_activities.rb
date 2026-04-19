class AddMaxSpeedToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :max_speed, :decimal, precision: 8, scale: 3
  end
end
