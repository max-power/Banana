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

ActiveRecord::Schema[8.1].define(version: 2026_04_24_200001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"
  enable_extension "postgis_raster"

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
    t.string "device"
    t.decimal "distance", precision: 15, scale: 3
    t.uuid "duplicate_of_id"
    t.integer "elapsed_time"
    t.boolean "elevation_corrected"
    t.integer "elevation_gain"
    t.integer "elevation_loss"
    t.datetime "end_time"
    t.decimal "max_speed", precision: 8, scale: 3
    t.integer "moving_time"
    t.string "name"
    t.string "share_token", null: false
    t.datetime "start_time"
    t.geometry "track_3857", limit: {srid: 3857, type: "geometry", has_z: true}
    t.string "type"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.integer "utc_offset"
    t.index ["duplicate_of_id"], name: "index_activities_on_duplicate_of_id"
    t.index ["share_token"], name: "index_activities_on_share_token", unique: true
    t.index ["track_3857"], name: "idx_activities_track_3857", using: :gist
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "activity_segments", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "activity_id", null: false
    t.datetime "created_at", null: false
    t.float "distance_m"
    t.datetime "end_time"
    t.geometry "geom", limit: {srid: 4326, type: "line_string", has_z: true}, null: false
    t.virtual "geom_3857", type: :geometry, limit: {srid: 3857, type: "line_string", has_z: true}, as: "st_transform(geom, 3857)", stored: true
    t.integer "moving_time_s"
    t.integer "segment_index", null: false
    t.datetime "start_time"
    t.datetime "updated_at", null: false
    t.index ["activity_id", "segment_index"], name: "idx_activity_segments_activity_order", unique: true
    t.index ["activity_id"], name: "index_activity_segments_on_activity_id"
    t.index ["geom"], name: "idx_activity_segments_geom", using: :gist
    t.index ["geom"], name: "index_activity_segments_on_geom", using: :gist
    t.index ["geom_3857"], name: "idx_activity_segments_geom_3857", using: :gist
    t.index ["start_time", "end_time"], name: "idx_activity_segments_time_range"
    t.check_constraint "st_npoints(geom) >= 2", name: "activity_segments_min_points"
  end

  create_table "activity_tiles", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "activity_id", null: false
    t.datetime "created_at", null: false
    t.binary "pixels", null: false
    t.integer "start_year"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.integer "x", null: false
    t.integer "y", null: false
    t.integer "z", null: false
    t.index ["activity_id"], name: "index_activity_tiles_on_activity_id"
    t.index ["user_id", "z", "x", "y"], name: "index_activity_tiles_on_user_id_and_z_and_x_and_y"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "last_active_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.uuid "user_id", null: false
    t.index ["token"], name: "index_sessions_on_token", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tour_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "activity_id", null: false
    t.datetime "created_at", null: false
    t.uuid "tour_id", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_id"], name: "index_tour_memberships_on_activity_id"
    t.index ["tour_id", "activity_id"], name: "index_tour_memberships_on_tour_id_and_activity_id", unique: true
    t.index ["tour_id"], name: "index_tour_memberships_on_tour_id"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest"
    t.boolean "public_profile", default: false, null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "users"
  add_foreign_key "activity_segments", "activities"
  add_foreign_key "activity_tiles", "activities", on_delete: :cascade
  add_foreign_key "sessions", "users"
  add_foreign_key "tour_memberships", "activities"
  add_foreign_key "tour_memberships", "activities", column: "tour_id"
end
