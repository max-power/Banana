class CreateActivityTiles < ActiveRecord::Migration[8.1]
  def change
    create_table :activity_tiles, id: :uuid do |t|
      t.uuid    :activity_id, null: false
      t.uuid    :user_id,     null: false
      t.integer :z,           null: false
      t.integer :x,           null: false
      t.integer :y,           null: false
      t.integer :start_year
      t.binary  :pixels,      null: false
      t.timestamps
    end

    add_index :activity_tiles, [ :user_id, :z, :x, :y ]
    add_index :activity_tiles, :activity_id
    add_foreign_key :activity_tiles, :activities, on_delete: :cascade
  end
end
