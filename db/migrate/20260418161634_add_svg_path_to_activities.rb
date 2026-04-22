class AddSVGPathToActivities < ActiveRecord::Migration[8.1]
  def change
    add_column :activities, :svg_path, :text
  end
end
