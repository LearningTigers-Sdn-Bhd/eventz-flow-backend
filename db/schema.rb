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

<<<<<<< HEAD
ActiveRecord::Schema[8.0].define(version: 2026_01_14_044845) do
=======
ActiveRecord::Schema[8.0].define(version: 2026_01_14_064202) do
>>>>>>> 26a1cbd (feat: add role column in tickets and visitors)
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "business_host_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "event_id", null: false
    t.string "business_matching_event_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_business_host_assignments_on_event_id"
    t.index ["user_id"], name: "index_business_host_assignments_on_user_id"
  end

  create_table "custom_requests", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.text "description"
    t.integer "quantity"
    t.integer "status"
    t.decimal "resolved_price", precision: 8, scale: 2
    t.text "response_notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exhibitor_kit_id"], name: "index_custom_requests_on_exhibitor_kit_id"
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

  create_table "event_exhibition_contractors", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "exhibition_contractor_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_exhibition_contractors_on_event_id", unique: true
    t.index ["exhibition_contractor_profile_id"], name: "idx_on_exhibition_contractor_profile_id_13ae474f9f"
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
    t.string "floor"
    t.jsonb "location_details", default: {}
    t.index ["event_id", "floor"], name: "index_event_locations_on_event_id_and_floor"
    t.index ["event_id", "name"], name: "index_event_locations_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_event_locations_on_event_id"
    t.index ["location_details"], name: "index_event_locations_on_location_details", using: :gin
  end

  create_table "event_printing_service_price_tiers", force: :cascade do |t|
    t.bigint "event_printing_service_id", null: false
    t.decimal "price", precision: 8, scale: 2
    t.datetime "start_date"
    t.datetime "end_date"
    t.string "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_printing_service_id"], name: "idx_on_event_printing_service_id_223ea011a4"
  end

  create_table "event_printing_services", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "printing_service_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_printing_services_on_event_id"
    t.index ["printing_service_id"], name: "index_event_printing_services_on_printing_service_id"
  end

  create_table "event_rentable_item_price_tiers", force: :cascade do |t|
    t.bigint "event_rentable_item_id", null: false
    t.decimal "price", precision: 8, scale: 2
    t.datetime "start_date"
    t.datetime "end_date"
    t.string "label"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_rentable_item_id"], name: "idx_on_event_rentable_item_id_8b9d958fd1"
  end

  create_table "event_rentable_items", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "rentable_item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_rentable_items_on_event_id"
    t.index ["rentable_item_id"], name: "index_event_rentable_items_on_rentable_item_id"
  end

  create_table "event_sponsorship_attachments", force: :cascade do |t|
    t.bigint "event_sponsorship_id", null: false
    t.bigint "event_sponsorship_payment_id"
    t.integer "media_type"
    t.integer "attachment_type"
    t.string "file_name"
    t.string "mime_type"
    t.integer "file_size"
    t.string "storage_disk"
    t.string "storage_path"
    t.bigint "uploaded_by_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_event_sponsorship_attachments_on_deleted_at"
    t.index ["event_sponsorship_id"], name: "index_event_sponsorship_attachments_on_event_sponsorship_id"
    t.index ["event_sponsorship_payment_id"], name: "idx_on_event_sponsorship_payment_id_b459754389"
    t.index ["uploaded_by_id"], name: "index_event_sponsorship_attachments_on_uploaded_by_id"
  end

  create_table "event_sponsorship_items", force: :cascade do |t|
    t.bigint "event_sponsorship_id", null: false
    t.integer "item_type"
    t.string "title"
    t.integer "quantity"
    t.decimal "unit_value", precision: 12, scale: 2
    t.decimal "total_value", precision: 12, scale: 2
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "received"
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.index ["created_by_id"], name: "index_event_sponsorship_items_on_created_by_id"
    t.index ["event_sponsorship_id"], name: "index_event_sponsorship_items_on_event_sponsorship_id"
    t.index ["updated_by_id"], name: "index_event_sponsorship_items_on_updated_by_id"
  end

  create_table "event_sponsorship_payments", force: :cascade do |t|
    t.bigint "event_sponsorship_id", null: false
    t.decimal "amount", precision: 12, scale: 2
    t.string "currency", default: "MYR"
    t.datetime "received_at"
    t.integer "method"
    t.string "reference_no"
    t.text "notes"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "created_by_id"
    t.bigint "updated_by_id"
    t.index ["created_by_id"], name: "index_event_sponsorship_payments_on_created_by_id"
    t.index ["deleted_at"], name: "index_event_sponsorship_payments_on_deleted_at"
    t.index ["event_sponsorship_id"], name: "index_event_sponsorship_payments_on_event_sponsorship_id"
    t.index ["updated_by_id"], name: "index_event_sponsorship_payments_on_updated_by_id"
  end

  create_table "event_sponsorship_tiers", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.text "description"
    t.integer "sponsorship_type_default"
    t.string "currency_default", default: "MYR"
    t.decimal "suggested_value", precision: 12, scale: 2
    t.integer "capacity"
    t.text "benefits"
    t.integer "sort_order"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_event_sponsorship_tiers_on_deleted_at"
    t.index ["event_id", "name"], name: "index_event_sponsorship_tiers_on_event_id_and_name", unique: true
    t.index ["event_id"], name: "index_event_sponsorship_tiers_on_event_id"
    t.index ["group_id"], name: "index_event_sponsorship_tiers_on_group_id"
  end

  create_table "event_sponsorships", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.bigint "event_id", null: false
    t.bigint "sponsor_id", null: false
    t.bigint "event_sponsorship_tier_id"
    t.string "tier_name_snapshot"
    t.string "title", null: false
    t.integer "sponsorship_type", default: 0
    t.string "currency", default: "MYR"
    t.decimal "total_sponsor_amount", precision: 12, scale: 2
    t.decimal "received_total", precision: 12, scale: 2, default: "0.0"
    t.datetime "last_received_at"
    t.text "description"
    t.integer "status", default: 0
    t.string "contact_name"
    t.string "contact_email"
    t.string "contact_whatsapp"
    t.string "contact_position"
    t.bigint "internal_owner_user_id"
    t.datetime "confirmed_at"
    t.datetime "cancelled_at"
    t.text "cancel_reason"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_event_sponsorships_on_deleted_at"
    t.index ["event_id", "sponsor_id", "title"], name: "index_event_sponsorships_uniqueness", unique: true
    t.index ["event_id"], name: "index_event_sponsorships_on_event_id"
    t.index ["event_sponsorship_tier_id"], name: "index_event_sponsorships_on_event_sponsorship_tier_id"
    t.index ["group_id"], name: "index_event_sponsorships_on_group_id"
    t.index ["internal_owner_user_id"], name: "index_event_sponsorships_on_internal_owner_user_id"
    t.index ["sponsor_id"], name: "index_event_sponsorships_on_sponsor_id"
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
    t.boolean "use_exhibitor_kit", default: false, null: false
    t.boolean "allow_contractor_printing_services", default: false
    t.boolean "use_business_matching", default: false
    t.string "business_matching_webhook_url"
    t.boolean "use_sponsorship", default: false
    t.index ["deleted_at"], name: "index_events_on_deleted_at"
    t.index ["slug"], name: "index_events_on_slug", unique: true
  end

  create_table "exhibition_contractor_profiles", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "company_name"
    t.string "contact_person"
    t.string "contact_email"
    t.string "contact_phone"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "allow_printing_services", default: true, null: false
    t.text "standard_package_info"
    t.index ["user_id"], name: "index_exhibition_contractor_profiles_on_user_id"
  end

  create_table "exhibitor_kit_admin_notes", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.bigint "user_id", null: false
    t.text "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_kit_admin_notes_on_exhibitor_kit_id"
    t.index ["user_id"], name: "index_exhibitor_kit_admin_notes_on_user_id"
  end

  create_table "exhibitor_kit_items", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.bigint "rentable_item_id", null: false
    t.integer "quantity"
    t.decimal "agreed_price", precision: 8, scale: 2
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "exhibitor_kit_payment_id"
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_kit_items_on_exhibitor_kit_id"
    t.index ["exhibitor_kit_payment_id"], name: "index_exhibitor_kit_items_on_exhibitor_kit_payment_id"
    t.index ["rentable_item_id"], name: "index_exhibitor_kit_items_on_rentable_item_id"
  end

  create_table "exhibitor_kit_payments", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.bigint "payee_id", null: false
    t.decimal "amount", precision: 10, scale: 2, default: "0.0"
    t.integer "status", default: 0
    t.string "payment_source"
    t.string "payment_proof_url"
    t.string "external_ref"
    t.text "note"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_kit_payments_on_exhibitor_kit_id"
    t.index ["payee_id"], name: "index_exhibitor_kit_payments_on_payee_id"
  end

  create_table "exhibitor_kit_printings", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.bigint "printing_service_id", null: false
    t.integer "quantity"
    t.decimal "agreed_price", precision: 8, scale: 2
    t.string "file_reference"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "exhibitor_kit_payment_id"
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_kit_printings_on_exhibitor_kit_id"
    t.index ["exhibitor_kit_payment_id"], name: "index_exhibitor_kit_printings_on_exhibitor_kit_payment_id"
    t.index ["printing_service_id"], name: "index_exhibitor_kit_printings_on_printing_service_id"
  end

  create_table "exhibitor_kits", force: :cascade do |t|
    t.bigint "event_vendor_id", null: false
    t.string "booth_number"
    t.integer "booth_type"
    t.string "booth_dimensions"
    t.boolean "side_wall_left_required", default: false
    t.boolean "side_wall_right_required", default: false
    t.string "name_on_fascia"
    t.boolean "fascia_upgrade_required", default: false
    t.string "company_name"
    t.text "company_address"
    t.string "pic_full_name"
    t.string "pic_contact_number"
    t.string "pic_email_address"
    t.text "special_requirements"
    t.string "digital_brochure_link"
    t.string "qr_code_url"
    t.boolean "indemnity_signed", default: false
    t.string "indemnity_document_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "payment_status", default: 0
    t.decimal "amount_paid", precision: 10, scale: 2
    t.text "payment_note"
    t.string "indemnity_link"
    t.index ["event_vendor_id"], name: "index_exhibitor_kits_on_event_vendor_id"
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

  create_table "exhibitor_team_member_limits", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.integer "team_member_limit"
    t.decimal "extra_team_member_fee", precision: 10, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_exhibitor_team_member_limits_on_event_id", unique: true
  end

  create_table "exhibitor_team_member_payments", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.bigint "payee_id"
    t.integer "extra_member_count", null: false
    t.decimal "fee_per_member", precision: 10, scale: 2, null: false
    t.decimal "amount", precision: 10, scale: 2, default: "0.0"
    t.integer "status", default: 0
    t.string "payment_source"
    t.string "external_ref"
    t.text "note"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_team_member_payments_on_exhibitor_kit_id"
    t.index ["payee_id"], name: "index_exhibitor_team_member_payments_on_payee_id"
  end

  create_table "exhibitor_team_members", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.string "full_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_team_members_on_exhibitor_kit_id"
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

  create_table "gift_winners", force: :cascade do |t|
    t.bigint "gift_id", null: false
    t.bigint "ticket_id"
    t.bigint "visitor_id"
    t.datetime "drawn_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["gift_id"], name: "index_gift_winners_on_gift_id"
    t.index ["ticket_id"], name: "index_gift_winners_on_ticket_id"
    t.index ["visitor_id"], name: "index_gift_winners_on_visitor_id"
    t.check_constraint "ticket_id IS NOT NULL AND visitor_id IS NULL OR ticket_id IS NULL AND visitor_id IS NOT NULL", name: "gift_winners_exactly_one_participant"
  end

  create_table "gifts", force: :cascade do |t|
    t.bigint "lucky_draw_session_id", null: false
    t.string "name", null: false
    t.integer "order", default: 0, null: false
    t.integer "winner_counts", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lucky_draw_session_id", "order"], name: "index_gifts_on_lucky_draw_session_id_and_order"
    t.index ["lucky_draw_session_id"], name: "index_gifts_on_lucky_draw_session_id"
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

  create_table "invalid_participants", force: :cascade do |t|
    t.bigint "lucky_draw_session_id", null: false
    t.bigint "ticket_id"
    t.bigint "visitor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["lucky_draw_session_id", "ticket_id"], name: "index_invalid_participants_on_session_id_and_ticket_id_unique", unique: true, where: "(ticket_id IS NOT NULL)"
    t.index ["lucky_draw_session_id", "visitor_id"], name: "index_invalid_participants_on_session_id_and_visitor_id_unique", unique: true, where: "(visitor_id IS NOT NULL)"
    t.index ["lucky_draw_session_id"], name: "index_invalid_participants_on_lucky_draw_session_id"
    t.index ["ticket_id"], name: "index_invalid_participants_on_ticket_id"
    t.index ["visitor_id"], name: "index_invalid_participants_on_visitor_id"
    t.check_constraint "ticket_id IS NOT NULL AND visitor_id IS NULL OR ticket_id IS NULL AND visitor_id IS NOT NULL", name: "invalid_participants_exactly_one_participant"
  end

  create_table "item_categories", force: :cascade do |t|
    t.string "name"
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "lucky_draw_sessions", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.date "draw_date"
    t.jsonb "draw_styles", default: {}
    t.jsonb "wrapper_background", default: {}
    t.boolean "use_gifts", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["draw_date"], name: "index_lucky_draw_sessions_on_draw_date"
    t.index ["draw_styles"], name: "index_lucky_draw_sessions_on_draw_styles", using: :gin
    t.index ["event_id"], name: "index_lucky_draw_sessions_on_event_id"
    t.index ["wrapper_background"], name: "index_lucky_draw_sessions_on_wrapper_background", using: :gin
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

  create_table "payment_details", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "bank_name", null: false
    t.string "account_number", null: false
    t.string "account_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_payment_details_on_user_id", unique: true
  end

  create_table "printing_services", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "unit_of_measure"
    t.decimal "default_price", precision: 8, scale: 2, default: "0.0"
    t.integer "status"
    t.bigint "item_category_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_category_id"], name: "index_printing_services_on_item_category_id"
    t.index ["user_id"], name: "index_printing_services_on_user_id"
  end

  create_table "rentable_items", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "unit_of_measure"
    t.decimal "default_price", precision: 8, scale: 2, default: "0.0"
    t.integer "status"
    t.bigint "item_category_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_category_id"], name: "index_rentable_items_on_item_category_id"
    t.index ["user_id"], name: "index_rentable_items_on_user_id"
  end

  create_table "resource_categories", force: :cascade do |t|
    t.string "name"
    t.string "slug", null: false
    t.text "description"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_resource_categories_on_deleted_at"
    t.index ["slug"], name: "index_resource_categories_on_slug", unique: true
  end

  create_table "resource_changelogs", force: :cascade do |t|
    t.bigint "resource_id", null: false
    t.bigint "changed_by_user_id", null: false
    t.string "title"
    t.text "article"
    t.string "slug"
    t.string "meta_description"
    t.bigint "resource_topic_id"
    t.bigint "resource_category_id"
    t.bigint "resource_media_type_id"
    t.integer "status"
    t.datetime "published_at"
    t.integer "view_counts"
    t.integer "priority"
    t.boolean "is_gated"
    t.boolean "is_official"
    t.text "rejection_reason"
    t.datetime "changed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["changed_at"], name: "index_resource_changelogs_on_changed_at"
    t.index ["changed_by_user_id"], name: "index_resource_changelogs_on_changed_by_user_id"
    t.index ["resource_id"], name: "index_resource_changelogs_on_resource_id"
  end

  create_table "resource_leads", force: :cascade do |t|
    t.string "email"
    t.string "name"
    t.string "phone"
    t.string "company_name"
    t.string "state"
    t.string "country"
    t.string "job_title"
    t.string "ip_address"
    t.datetime "accessed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "resource_id", null: false
    t.index ["resource_id"], name: "index_resource_leads_on_resource_id"
  end

  create_table "resource_media_types", force: :cascade do |t|
    t.string "name"
    t.string "slug", null: false
    t.text "description"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_resource_media_types_on_deleted_at"
    t.index ["slug"], name: "index_resource_media_types_on_slug", unique: true
  end

  create_table "resource_topics", force: :cascade do |t|
    t.string "name"
    t.string "slug", null: false
    t.text "description"
    t.string "logo"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_resource_topics_on_deleted_at"
    t.index ["slug"], name: "index_resource_topics_on_slug", unique: true
  end

  create_table "resource_write_permissions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.boolean "is_official", default: false
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_resource_write_permissions_on_user_id", unique: true
  end

  create_table "resources", force: :cascade do |t|
    t.string "title"
    t.text "article"
    t.string "slug", null: false
    t.string "meta_description"
    t.bigint "user_id", null: false
    t.bigint "resource_topic_id", null: false
    t.bigint "resource_category_id", null: false
    t.bigint "resource_media_type_id", null: false
    t.integer "status", default: 0
    t.datetime "published_at"
    t.datetime "deleted_at"
    t.integer "view_counts", default: 0
    t.integer "priority", default: 10
    t.boolean "is_gated", default: false
    t.boolean "is_official", default: false
    t.text "rejection_reason"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deleted_at"], name: "index_resources_on_deleted_at"
    t.index ["resource_category_id"], name: "index_resources_on_resource_category_id"
    t.index ["resource_media_type_id"], name: "index_resources_on_resource_media_type_id"
    t.index ["resource_topic_id"], name: "index_resources_on_resource_topic_id"
    t.index ["slug"], name: "index_resources_on_slug", unique: true
    t.index ["user_id"], name: "index_resources_on_user_id"
  end

  create_table "sponsors", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "name", null: false
    t.string "website"
    t.string "industry"
    t.string "default_email"
    t.string "default_whatsapp"
    t.string "default_contact_name"
    t.string "default_contact_position"
    t.text "notes"
    t.string "logo_path"
    t.boolean "is_active", default: true
    t.bigint "created_by_id"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_sponsors_on_created_by_id"
    t.index ["deleted_at"], name: "index_sponsors_on_deleted_at"
    t.index ["group_id", "name"], name: "index_sponsors_on_group_id_and_name", unique: true
    t.index ["group_id"], name: "index_sponsors_on_group_id"
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
    t.string "role"
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
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category"
    t.string "person_in_charge"
    t.text "address"
    t.text "notes"
    t.text "company_profile"
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
    t.jsonb "custom_fields_data", default: {}
    t.boolean "checked_in", default: false, null: false
    t.datetime "check_in_at"
    t.bigint "scanned_by_id"
    t.string "role"
    t.index ["event_id"], name: "index_visitors_on_event_id"
    t.index ["public_id"], name: "index_visitors_on_public_id", unique: true
    t.index ["scanned_by_id"], name: "index_visitors_on_scanned_by_id"
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
    t.string "voucher_category"
    t.integer "status", default: 0
    t.integer "voucher_type"
    t.boolean "is_unlimited", default: false, null: false
    t.index ["event_id"], name: "index_vouchers_on_event_id"
    t.index ["status"], name: "index_vouchers_on_status"
    t.index ["vendor_id"], name: "index_vouchers_on_vendor_id"
    t.index ["voucher_code"], name: "index_vouchers_on_voucher_code"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "users"
  add_foreign_key "business_host_assignments", "events"
  add_foreign_key "business_host_assignments", "users"
  add_foreign_key "custom_requests", "exhibitor_kits"
  add_foreign_key "email_verifications", "users"
  add_foreign_key "event_assignments", "events"
  add_foreign_key "event_assignments", "users"
  add_foreign_key "event_exhibition_contractors", "events"
  add_foreign_key "event_exhibition_contractors", "exhibition_contractor_profiles"
  add_foreign_key "event_location_members", "event_locations"
  add_foreign_key "event_location_members", "users", column: "member_id"
  add_foreign_key "event_locations", "events"
  add_foreign_key "event_printing_service_price_tiers", "event_printing_services"
  add_foreign_key "event_printing_services", "events"
  add_foreign_key "event_printing_services", "printing_services"
  add_foreign_key "event_rentable_item_price_tiers", "event_rentable_items"
  add_foreign_key "event_rentable_items", "events"
  add_foreign_key "event_rentable_items", "rentable_items"
  add_foreign_key "event_sponsorship_attachments", "event_sponsorship_payments"
  add_foreign_key "event_sponsorship_attachments", "event_sponsorships"
  add_foreign_key "event_sponsorship_attachments", "users", column: "uploaded_by_id"
  add_foreign_key "event_sponsorship_items", "event_sponsorships"
  add_foreign_key "event_sponsorship_items", "users", column: "created_by_id"
  add_foreign_key "event_sponsorship_items", "users", column: "updated_by_id"
  add_foreign_key "event_sponsorship_payments", "event_sponsorships"
  add_foreign_key "event_sponsorship_payments", "users", column: "created_by_id"
  add_foreign_key "event_sponsorship_payments", "users", column: "updated_by_id"
  add_foreign_key "event_sponsorship_tiers", "events"
  add_foreign_key "event_sponsorship_tiers", "groups"
  add_foreign_key "event_sponsorships", "event_sponsorship_tiers"
  add_foreign_key "event_sponsorships", "events"
  add_foreign_key "event_sponsorships", "groups"
  add_foreign_key "event_sponsorships", "sponsors"
  add_foreign_key "event_sponsorships", "users", column: "internal_owner_user_id"
  add_foreign_key "event_vendors", "events"
  add_foreign_key "event_vendors", "exhibitor_owners"
  add_foreign_key "event_vendors", "users", column: "vendor_id"
  add_foreign_key "exhibition_contractor_profiles", "users"
  add_foreign_key "exhibitor_kit_admin_notes", "exhibitor_kits"
  add_foreign_key "exhibitor_kit_admin_notes", "users"
  add_foreign_key "exhibitor_kit_items", "exhibitor_kit_payments"
  add_foreign_key "exhibitor_kit_items", "exhibitor_kits"
  add_foreign_key "exhibitor_kit_items", "rentable_items"
  add_foreign_key "exhibitor_kit_payments", "exhibitor_kits"
  add_foreign_key "exhibitor_kit_payments", "users", column: "payee_id"
  add_foreign_key "exhibitor_kit_printings", "exhibitor_kit_payments"
  add_foreign_key "exhibitor_kit_printings", "exhibitor_kits"
  add_foreign_key "exhibitor_kit_printings", "printing_services"
  add_foreign_key "exhibitor_kits", "event_vendors"
  add_foreign_key "exhibitor_team_member_limits", "events"
  add_foreign_key "exhibitor_team_member_payments", "exhibitor_kits"
  add_foreign_key "exhibitor_team_member_payments", "users", column: "payee_id"
  add_foreign_key "exhibitor_team_members", "exhibitor_kits"
  add_foreign_key "export_logs", "events"
  add_foreign_key "gift_winners", "gifts"
  add_foreign_key "gift_winners", "tickets", on_delete: :cascade
  add_foreign_key "gift_winners", "visitors", on_delete: :cascade
  add_foreign_key "gifts", "lucky_draw_sessions"
  add_foreign_key "group_affiliates", "groups"
  add_foreign_key "group_affiliates", "users", column: "vendor_id"
  add_foreign_key "group_members", "groups"
  add_foreign_key "group_members", "users"
  add_foreign_key "invalid_participants", "lucky_draw_sessions"
  add_foreign_key "invalid_participants", "tickets", on_delete: :cascade
  add_foreign_key "invalid_participants", "visitors", on_delete: :cascade
  add_foreign_key "lucky_draw_sessions", "events"
  add_foreign_key "password_resets", "users"
  add_foreign_key "payment_details", "users"
  add_foreign_key "printing_services", "item_categories"
  add_foreign_key "printing_services", "users"
  add_foreign_key "rentable_items", "item_categories"
  add_foreign_key "rentable_items", "users"
  add_foreign_key "resource_changelogs", "resources"
  add_foreign_key "resource_changelogs", "users", column: "changed_by_user_id"
  add_foreign_key "resource_leads", "resources"
  add_foreign_key "resource_write_permissions", "users"
  add_foreign_key "resources", "resource_categories"
  add_foreign_key "resources", "resource_media_types"
  add_foreign_key "resources", "resource_topics"
  add_foreign_key "resources", "users"
  add_foreign_key "sponsors", "groups"
  add_foreign_key "sponsors", "users", column: "created_by_id"
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
  add_foreign_key "visitors", "users", column: "scanned_by_id"
  add_foreign_key "voucher_redemption_logs", "users", column: "redeemer_staff_id"
  add_foreign_key "voucher_redemption_logs", "vouchers"
  add_foreign_key "voucher_usages", "vouchers"
  add_foreign_key "vouchers", "events"
  add_foreign_key "vouchers", "users", column: "vendor_id"
end
