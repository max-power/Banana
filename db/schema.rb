# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_01_17_101922) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "active_storage_attachments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.uuid "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "activities", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "activity_type"
    t.decimal "average_speed", precision: 8, scale: 2
    t.datetime "created_at", null: false
    t.text "description"
    t.decimal "distance", precision: 15, scale: 3
    t.integer "elapsed_time"
    t.integer "elevation_gain"
    t.datetime "end_time"
    t.integer "moving_time"
    t.string "name"
    t.datetime "start_time"
    t.uuid "tour_id"
    t.geography "track", limit: {srid: 4326, type: "line_string", has_z: true, geographic: true}
    t.geometry "track_3857", limit: {srid: 3857, type: "line_string", has_z: true}
    t.string "type"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["tour_id"], name: "index_activities_on_tour_id"
    t.index ["track"], name: "activities_geom_idx", using: :gist
    t.index ["track_3857"], name: "activities_track_3857_gix", using: :gist
    t.index ["track_3857"], name: "idx_activities_track_3857", using: :gist
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "activities", column: "tour_id"
  add_foreign_key "activities", "users"

  create_view "activity_mvts", materialized: true, sql_definition: <<-SQL
      WITH zoom_levels AS (
           SELECT generate_series(0, 15) AS z
          )
   SELECT a.id,
      z.z AS zoom_level,
          CASE
              WHEN (z.z < 10) THEN st_simplify(a.track_3857, (200)::double precision)
              WHEN (z.z < 13) THEN st_simplify(a.track_3857, (50)::double precision)
              ELSE a.track_3857
          END AS geom
     FROM (activities a
       CROSS JOIN zoom_levels z)
    WHERE ((a.track_3857 IS NOT NULL) AND (st_length(a.track_3857) > (0)::double precision));
  SQL
  add_index "activity_mvts", ["geom"], name: "index_activity_mvts_on_geom", using: :gist
  add_index "activity_mvts", ["id", "zoom_level"], name: "idx_activities_mvt_unique", unique: true
  add_index "activity_mvts", ["zoom_level"], name: "index_activity_mvts_on_zoom_level"

end
