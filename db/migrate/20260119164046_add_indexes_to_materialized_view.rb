class AddIndexesToMaterializedView < ActiveRecord::Migration[8.1]
  def change
      add_index :activity_segments_mvts, [:id, :zoom_level], unique: true, name: 'idx_mvt_unique_refresh'
      add_index :activity_segments_mvts, :geom, name: 'idx_mvt_geom', using: :gist
  end
end
