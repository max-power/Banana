class CreateActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :activities, id: :uuid do |t|
        t.references "user", null: false, foreign_key: true, type: :uuid
        t.references "tour", null: true, foreign_key: { to_table: :activities }, type: :uuid
        t.string "type"
        t.string "activity_type"
        t.string "name"
        t.text "description"
        t.decimal "distance", precision: 15, scale: 3
        t.datetime "start_time"
        t.datetime "end_time"
        t.integer "moving_time"
        t.integer "elapsed_time"
        t.integer "elevation_gain"
        t.decimal "average_speed", precision: 8, scale: 2
        t.geography "track", limit: {srid: 4326, type: "linestring", geographic: true, has_z: true}
        t.timestamps
        t.index ["track"], name: "activities_geom_idx", using: :gist
    end
  end
end
