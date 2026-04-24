class AddUtcOffsetToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :utc_offset, :integer
  end
end
