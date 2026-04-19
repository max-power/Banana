class DropSVGPathFromActivities < ActiveRecord::Migration[8.1]
  def change
    remove_column :activities, :svg_path, :text
  end
end
