class CreateActivityMvts < ActiveRecord::Migration[8.1]
  def change
    create_view :activity_mvts, materialized: true

    # Add indexes for performance
    add_index :activity_mvts, :zoom_level
    add_index :activity_mvts, [:id, :zoom_level], unique: true, name: 'idx_activities_mvt_unique'
    add_index :activity_mvts, :geom, using: :gist
  end
end
