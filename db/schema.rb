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

ActiveRecord::Schema[8.0].define(version: 2025_11_20_090411) do
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

  create_table "email_verifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "hashed_code", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_email_verifications_on_user_id"
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
    t.boolean "is_unlimited", default: false, null: false
    t.index ["event_id", "name"], name: "index_event_locations_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_event_locations_on_event_id"
  end

  create_table "event_vendors", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "vendor_id", null: false
    t.string "redirect_url"
    t.string "poster_url"
    t.string "type", null: false
    t.bigint "exhibitor_owner_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "qr_url"
    t.index ["event_id", "vendor_id"], name: "index_event_vendors_on_event_and_vendor", unique: true
    t.index ["exhibitor_owner_id"], name: "index_event_vendors_on_exhibitor_owner_id"
    t.index ["type"], name: "index_event_vendors_on_type"
    t.index ["vendor_id"], name: "index_event_vendors_on_vendor_id"
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
    t.boolean "use_ticket", default: true, null: false
    t.datetime "deleted_at"
    t.string "slug"
    t.index ["deleted_at"], name: "index_events_on_deleted_at"
    t.index ["slug"], name: "index_events_on_slug", unique: true
  end

  create_table "exhibitor_owners", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.string "contact_email"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_exhibitor_owners_on_name"
  end

  create_table "export_logs", force: :cascade do |t|
    t.string "type"
    t.string "sheet_path"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "event_id", null: false
    t.index ["event_id"], name: "index_export_logs_on_event_id"
    t.index ["type", "created_at"], name: "index_export_logs_on_type_and_created_at"
  end

  create_table "group_affiliates", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "vendor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "vendor_id"], name: "index_group_affiliates_on_group_id_and_vendor_id", unique: true
    t.index ["group_id"], name: "index_group_affiliates_on_group_id"
    t.index ["vendor_id"], name: "index_group_affiliates_on_vendor_id"
  end

  create_table "group_members", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "user_id", null: false
    t.boolean "has_manager_access", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "user_id"], name: "index_group_members_on_group_id_and_user_id", unique: true
    t.index ["group_id"], name: "index_group_members_on_group_id"
    t.index ["user_id"], name: "index_group_members_on_user_id"
  end

  create_table "groups", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_groups_on_name"
  end

  create_table "orders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "password_resets", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_password_resets_on_expires_at"
    t.index ["user_id"], name: "index_password_resets_on_user_id"
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
    t.string "attendee_email"
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
    t.string "attendee_email_norm"
    t.string "attendee_phone_norm"
    t.string "attendee_name_norm"
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_tickets_on_deleted_at"
    t.index ["event_id", "attendee_email_norm"], name: "idx_tickets_event_email_norm", where: "(attendee_email_norm IS NOT NULL)"
    t.index ["event_id", "attendee_phone_norm"], name: "idx_tickets_event_phone_norm", where: "(attendee_phone_norm IS NOT NULL)"
    t.index ["event_id", "status"], name: "index_tickets_on_event_id_and_status"
    t.index ["event_id", "ticket_type_id", "attendee_name_norm"], name: "idx_tickets_event_type_name_norm_unique", unique: true, where: "((attendee_email_norm IS NULL) AND (attendee_phone_norm IS NULL))"
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
    t.string "jti", null: false
    t.datetime "email_verified_at"
    t.bigint "created_by_id"
    t.index ["created_by_id"], name: "index_users_on_created_by_id"
    t.index ["email"], name: "index_users_on_email"
    t.index ["jti"], name: "index_users_on_jti", unique: true
    t.index ["status"], name: "index_users_on_status"
  end

  create_table "vendor_profiles", force: :cascade do |t|
    t.bigint "vendor_id", null: false
    t.string "image_path"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.string "person_in_charge"
    t.text "address"
    t.text "notes"
    t.index ["vendor_id"], name: "index_vendor_profiles_on_vendor_id", unique: true
  end

  create_table "visitor_vendor_stamps", force: :cascade do |t|
    t.bigint "visitor_id", null: false
    t.bigint "event_vendor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_vendor_id"], name: "index_visitor_vendor_stamps_on_event_vendor_id"
    t.index ["visitor_id", "event_vendor_id"], name: "index_visitor_vendor_stamps_on_visitor_and_event_vendor", unique: true
    t.index ["visitor_id"], name: "index_visitor_vendor_stamps_on_visitor_id"
  end

  create_table "visitors", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.uuid "public_id", default: -> { "gen_random_uuid()" }, null: false
    t.string "full_name"
    t.string "gender"
    t.integer "age"
    t.string "phone"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_visitors_on_event_id"
    t.index ["public_id"], name: "index_visitors_on_public_id", unique: true
  end

  create_table "voucher_redemption_logs", force: :cascade do |t|
    t.bigint "voucher_id", null: false
    t.bigint "redeemer_staff_id"
    t.datetime "redemption_timestamp"
    t.string "redemption_location"
    t.string "redemption_status"
    t.decimal "transaction_gross_amount", precision: 10, scale: 2
    t.decimal "discount_applied_value", precision: 10, scale: 2
    t.decimal "transaction_net_amount", precision: 10, scale: 2
    t.datetime "cancellation_timestamp"
    t.text "cancellation_reason"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "redeemer_id"
    t.string "redeemer_type"
    t.index ["redeemer_staff_id"], name: "index_voucher_redemption_logs_on_redeemer_staff_id"
    t.index ["redeemer_type", "redeemer_id"], name: "index_voucher_redemption_logs_on_redeemer"
    t.index ["voucher_id"], name: "index_voucher_redemption_logs_on_voucher_id"
  end

  create_table "voucher_usages", force: :cascade do |t|
    t.bigint "voucher_id", null: false
    t.integer "redemption_count"
    t.datetime "first_view_timestamp"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "redeemer_id"
    t.integer "redeemer_type", limit: 2
    t.index ["redeemer_type", "redeemer_id"], name: "index_voucher_usages_on_redeemer_type_and_redeemer_id"
    t.index ["voucher_id"], name: "index_voucher_usages_on_voucher_id"
  end

  create_table "vouchers", force: :cascade do |t|
    t.string "title"
    t.uuid "voucher_uuid", default: -> { "gen_random_uuid()" }, null: false
    t.text "description"
    t.bigint "vendor_id"
    t.bigint "event_id"
    t.string "voucher_code"
    t.date "start_date"
    t.date "end_date"
    t.time "start_time"
    t.time "end_time"
    t.integer "total_redemption_available"
    t.integer "redeemed_count"
    t.integer "max_redemptions_per_user"
    t.text "user_role_restriction"
    t.decimal "voucher_value", precision: 10, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image_path"
    t.string "voucher_category"
    t.integer "status", default: 0
    t.integer "voucher_type"
    t.index ["event_id"], name: "index_vouchers_on_event_id"
    t.index ["status"], name: "index_vouchers_on_status"
    t.index ["vendor_id"], name: "index_vouchers_on_vendor_id"
    t.index ["voucher_code"], name: "index_vouchers_on_voucher_code"
  end

  add_foreign_key "api_keys", "users"
  add_foreign_key "email_verifications", "users"
  add_foreign_key "event_assignments", "events"
  add_foreign_key "event_assignments", "users"
  add_foreign_key "event_location_members", "event_locations"
  add_foreign_key "event_location_members", "users", column: "member_id"
  add_foreign_key "event_locations", "events"
  add_foreign_key "event_vendors", "events"
  add_foreign_key "event_vendors", "exhibitor_owners"
  add_foreign_key "event_vendors", "users", column: "vendor_id"
  add_foreign_key "export_logs", "events"
  add_foreign_key "group_affiliates", "groups"
  add_foreign_key "group_affiliates", "users", column: "vendor_id"
  add_foreign_key "group_members", "groups"
  add_foreign_key "group_members", "users"
  add_foreign_key "password_resets", "users"
  add_foreign_key "ticket_types", "events"
  add_foreign_key "tickets", "events"
  add_foreign_key "tickets", "ticket_types"
  add_foreign_key "tickets", "users"
  add_foreign_key "tickets", "users", column: "scanned_by_id"
  add_foreign_key "users", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "vendor_profiles", "users", column: "vendor_id"
  add_foreign_key "visitor_vendor_stamps", "event_vendors"
  add_foreign_key "visitor_vendor_stamps", "visitors"
  add_foreign_key "visitors", "events"
  add_foreign_key "voucher_redemption_logs", "users", column: "redeemer_staff_id"
  add_foreign_key "voucher_redemption_logs", "vouchers"
  add_foreign_key "voucher_usages", "vouchers"
  add_foreign_key "vouchers", "events"
  add_foreign_key "vouchers", "users", column: "vendor_id"
end
