class AddDuplicateOfToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :duplicate_of_id, :uuid
    add_index  :activities, :duplicate_of_id
  end
end
