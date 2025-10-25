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

ActiveRecord::Schema[8.0].define(version: 2025_10_24_065322) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "api_keys", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "key_hash", null: false
    t.datetime "last_used_at"
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key_hash"], name: "index_api_keys_on_key_hash", unique: true
    t.index ["last_used_at"], name: "index_api_keys_on_last_used_at"
    t.index ["user_id"], name: "index_api_keys_on_user_id"
  end

  create_table "event_admins", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_admins_on_event_id"
    t.index ["user_id"], name: "index_event_admins_on_user_id"
  end

  create_table "event_assignments", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "user_id"], name: "index_event_assignments_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_assignments_on_event_id"
    t.index ["user_id"], name: "index_event_assignments_on_user_id"
  end

  create_table "event_location_members", force: :cascade do |t|
    t.bigint "event_location_id", null: false
    t.bigint "member_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_location_id", "member_id"], name: "idx_on_event_location_id_member_id_fa34732f50", unique: true
    t.index ["event_location_id"], name: "index_event_location_members_on_event_location_id"
    t.index ["member_id"], name: "index_event_location_members_on_member_id"
  end

  create_table "event_locations", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.integer "scan_limit", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "name"], name: "index_event_locations_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_event_locations_on_event_id"
  end

  create_table "event_team_members", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_team_members_on_event_id"
    t.index ["user_id"], name: "index_event_team_members_on_user_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "status", default: 0, null: false
    t.boolean "multiple_scans", default: false, null: false
    t.datetime "start_date"
    t.datetime "end_date"
    t.string "webhook_url"
    t.jsonb "labels_data", default: {}
    t.boolean "visibility", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "payment_status", default: 0
    t.decimal "price", precision: 8, scale: 2, default: "0.0"
    t.boolean "published", default: false, null: false
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "refresh_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_hash", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["revoked_at"], name: "index_refresh_tokens_on_revoked_at"
    t.index ["token_hash"], name: "index_refresh_tokens_on_token_hash", unique: true
    t.index ["user_id"], name: "index_refresh_tokens_on_user_id"
  end

  create_table "ticket_types", force: :cascade do |t|
    t.bigint "event_id"
    t.string "name", null: false
    t.decimal "price", precision: 8, scale: 2, default: "0.0", null: false
    t.integer "quantity", default: 0, null: false
    t.integer "max_per_order", default: 10, null: false
    t.datetime "sale_starts_at"
    t.datetime "sale_ends_at"
    t.integer "status", default: 0
    t.boolean "hidden", default: false
    t.jsonb "custom_fields_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "status"], name: "index_ticket_types_on_event_id_and_status"
    t.index ["event_id"], name: "index_ticket_types_on_event_id"
  end

  create_table "tickets", force: :cascade do |t|
    t.uuid "public_id", default: -> { "gen_random_uuid()" }, null: false
    t.bigint "event_id", null: false
    t.bigint "ticket_type_id", null: false
    t.bigint "user_id"
    t.string "attendee_name", null: false
    t.string "attendee_email", null: false
    t.string "attendee_phone"
    t.boolean "checked_in", default: false, null: false
    t.datetime "check_in_at"
    t.bigint "scanned_by_id"
    t.integer "status", default: 0, null: false
    t.integer "payment_status", default: 0, null: false
    t.string "payment_screenshot_url"
    t.string "transaction_id"
    t.string "payment_method"
    t.jsonb "custom_fields_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "status"], name: "index_tickets_on_event_id_and_status"
    t.index ["event_id"], name: "index_tickets_on_event_id"
    t.index ["public_id"], name: "index_tickets_on_public_id", unique: true
    t.index ["scanned_by_id"], name: "index_tickets_on_scanned_by_id"
    t.index ["ticket_type_id"], name: "index_tickets_on_ticket_type_id"
    t.index ["user_id"], name: "index_tickets_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "full_name"
    t.string "phone"
    t.integer "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "status", default: 1, null: false
    t.string "jti"
    t.index ["email"], name: "index_users_on_email"
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["status"], name: "index_users_on_status"
  end

  add_foreign_key "api_keys", "users"
  add_foreign_key "event_assignments", "events"
  add_foreign_key "event_assignments", "users"
  add_foreign_key "event_location_members", "event_locations"
  add_foreign_key "event_location_members", "users", column: "member_id"
  add_foreign_key "event_locations", "events"
  add_foreign_key "refresh_tokens", "users"
  add_foreign_key "ticket_types", "events"
  add_foreign_key "tickets", "events"
  add_foreign_key "tickets", "ticket_types"
  add_foreign_key "tickets", "users"
  add_foreign_key "tickets", "users", column: "scanned_by_id"
end
