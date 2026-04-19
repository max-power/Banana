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

ActiveRecord::Schema[8.1].define(version: 2026_04_19_000003) do
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
    t.decimal "distance", precision: 15, scale: 3
    t.uuid "duplicate_of_id"
    t.integer "elapsed_time"
    t.integer "elevation_gain"
    t.integer "elevation_loss"
    t.datetime "end_time"
    t.decimal "max_speed", precision: 8, scale: 3
    t.integer "moving_time"
    t.string "name"
    t.string "share_token", null: false
    t.datetime "start_time"
    t.uuid "tour_id"
    t.geography "track", limit: {srid: 4326, type: "line_string", has_z: true, geographic: true}
    t.geometry "track_3857", limit: {srid: 3857, type: "geometry", has_z: true}
    t.string "type"
    t.datetime "updated_at", null: false
    t.uuid "user_id", null: false
    t.index ["duplicate_of_id"], name: "index_activities_on_duplicate_of_id"
    t.index ["share_token"], name: "index_activities_on_share_token", unique: true
    t.index ["tour_id"], name: "index_activities_on_tour_id"
    t.index ["track"], name: "activities_geom_idx", using: :gist
    t.index ["track_3857"], name: "idx_activities_track_3857", using: :gist
    t.index ["user_id"], name: "index_activities_on_user_id"
  end

  create_table "activity_points", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "activity_segment_id", null: false
    t.geometry "geom", limit: {srid: 3857, type: "st_point"}, null: false
    t.index ["activity_segment_id"], name: "idx_activity_points_activity_segment_id"
    t.index ["geom"], name: "idx_activity_points_geom", using: :gist
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

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.boolean "public_profile", default: false, null: false
    t.datetime "updated_at", null: false
    t.datetime "verified_at"
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "activities", "activities", column: "tour_id"
  add_foreign_key "activities", "users"
  add_foreign_key "activity_points", "activity_segments", name: "fk_activity_points_segments", on_delete: :cascade
  add_foreign_key "activity_segments", "activities"
  add_foreign_key "sessions", "users"

  create_view "activity_segments_mvts", materialized: true, sql_definition: <<-SQL
      WITH zoom_levels AS (
           SELECT generate_series(0, 15) AS z
          )
   SELECT s.id,
      a.user_id,
      a.activity_type,
      a.name AS activity_name,
      a.start_time AS start_date,
      z.z AS zoom_level,
          CASE
              WHEN (z.z < 10) THEN st_simplify(st_transform(s.geom, 3857), (200)::double precision)
              WHEN (z.z < 13) THEN st_simplify(st_transform(s.geom, 3857), (50)::double precision)
              ELSE st_transform(s.geom, 3857)
          END AS geom
     FROM ((activity_segments s
       JOIN activities a ON ((s.activity_id = a.id)))
       CROSS JOIN zoom_levels z)
    WHERE ((s.geom IS NOT NULL) AND (NOT st_isempty(s.geom)) AND (st_length(st_transform(s.geom, 3857)) > (
          CASE
              WHEN (z.z <= 7) THEN 500
              WHEN (z.z <= 10) THEN 100
              ELSE 0
          END)::double precision));
  SQL
  add_index "activity_segments_mvts", ["geom"], name: "idx_mvt_geom", using: :gist
  add_index "activity_segments_mvts", ["id", "zoom_level"], name: "idx_mvt_unique_refresh", unique: true

end
