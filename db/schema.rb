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

ActiveRecord::Schema[8.0].define(version: 2026_08_03_090000) do
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
    t.bigint "event_id"
    t.string "scope", default: "read_only", null: false
    t.index ["event_id"], name: "index_api_keys_on_event_id"
    t.index ["key_hash"], name: "index_api_keys_on_key_hash", unique: true
    t.index ["last_used_at"], name: "index_api_keys_on_last_used_at"
    t.index ["scope"], name: "index_api_keys_on_scope"
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

  create_table "business_matching_availabilities", force: :cascade do |t|
    t.bigint "business_matching_session_id", null: false
    t.bigint "host_user_id"
    t.date "day", null: false
    t.string "start_time", null: false
    t.string "end_time", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "business_matching_participant_id"
    t.index ["business_matching_participant_id"], name: "index_bm_availabilities_on_participant_id"
    t.index ["business_matching_session_id", "host_user_id", "day"], name: "idx_bm_availabilities_unique"
    t.index ["business_matching_session_id"], name: "index_bm_availabilities_on_bm_session_id"
    t.index ["host_user_id"], name: "index_business_matching_availabilities_on_host_user_id"
  end

  create_table "business_matching_bookings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "business_matching_session_id", null: false
    t.bigint "host_user_id"
    t.string "name", null: false
    t.string "email", null: false
    t.string "phone", null: false
    t.date "booking_date", null: false
    t.string "booking_time", null: false
    t.integer "duration", default: 30, null: false
    t.string "status", default: "Pending", null: false
    t.string "payment_status", default: "Pending", null: false
    t.string "attendance"
    t.text "host_comment"
    t.decimal "potential_deal_value", precision: 12, scale: 2, default: "0.0"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "requester_participant_id"
    t.bigint "receiver_participant_id"
    t.index ["business_matching_session_id"], name: "index_bm_bookings_on_bm_session_id"
    t.index ["host_user_id", "booking_date", "booking_time"], name: "index_bm_bookings_host_time_unique", unique: true, where: "((status)::text <> 'Cancelled'::text)"
    t.index ["host_user_id"], name: "index_business_matching_bookings_on_host_user_id"
    t.index ["receiver_participant_id", "booking_date", "booking_time"], name: "index_bm_bookings_receiver_time_unique", unique: true, where: "((status)::text <> 'Cancelled'::text)"
    t.index ["receiver_participant_id"], name: "index_bm_bookings_on_receiver_participant_id"
    t.index ["requester_participant_id"], name: "index_bm_bookings_on_requester_participant_id"
  end

  create_table "business_matching_participants", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "registerable_type", null: false
    t.bigint "registerable_id", null: false
    t.string "magic_token", null: false
    t.jsonb "profile_data", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "registerable_type", "registerable_id"], name: "index_bm_participants_uniqueness", unique: true
    t.index ["event_id"], name: "index_business_matching_participants_on_event_id"
    t.index ["magic_token"], name: "index_business_matching_participants_on_magic_token", unique: true
    t.index ["registerable_type", "registerable_id"], name: "index_business_matching_participants_on_registerable"
  end

  create_table "business_matching_sessions", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.integer "slot_duration", default: 30, null: false
    t.string "location"
    t.string "admin_email"
    t.string "admin_wa_number"
    t.string "start_time", default: "09:00", null: false
    t.string "end_time", default: "17:00", null: false
    t.boolean "is_active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_business_matching_sessions_on_event_id"
  end

  create_table "certificate_templates", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.integer "status", default: 0, null: false
    t.string "orientation", default: "landscape", null: false
    t.integer "canvas_width", default: 1123, null: false
    t.integer "canvas_height", default: 794, null: false
    t.jsonb "fields", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_certificate_templates_on_event_id", unique: true
    t.index ["status"], name: "index_certificate_templates_on_status"
  end

  create_table "check_in_displays", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "font_family", default: "Inter"
    t.integer "font_size", default: 72
    t.integer "animation_type", default: 0
    t.boolean "is_bold", default: false
    t.string "name_color", default: "#FFFFFF"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "voice_enabled", default: true
    t.string "voice_type", default: "ms-MY-Wavenet-A"
    t.string "welcome_text", default: "Welcome"
    t.string "idle_mode"
    t.string "announcement_mode"
    t.integer "announcement_duration"
    t.boolean "show_seating_plan", default: false
    t.integer "seating_plan_sidebar_position", default: 0
    t.bigint "active_plan_id"
    t.string "seating_announcement_template"
    t.integer "seating_plan_duration"
    t.jsonb "elevenlabs_settings", default: {}
    t.jsonb "voice_rules", default: []
    t.string "script_tone"
    t.index ["active_plan_id"], name: "index_check_in_displays_on_active_plan_id"
    t.index ["event_id"], name: "index_check_in_displays_on_event_id", unique: true
  end

  create_table "cloned_voices", force: :cascade do |t|
    t.bigint "event_id"
    t.bigint "creator_id", null: false
    t.string "elevenlabs_id"
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.jsonb "settings", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id", null: false
    t.index ["creator_id"], name: "index_cloned_voices_on_creator_id"
    t.index ["elevenlabs_id"], name: "index_cloned_voices_on_elevenlabs_id", unique: true
    t.index ["event_id"], name: "index_cloned_voices_on_event_id"
    t.index ["owner_id"], name: "index_cloned_voices_on_owner_id"
  end

  create_table "credit_deductions", force: :cascade do |t|
    t.bigint "event_id"
    t.string "channel", null: false
    t.integer "credits", null: false
    t.string "recipient"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id", null: false
    t.index ["event_id"], name: "index_credit_deductions_on_event_id"
    t.index ["owner_id"], name: "index_credit_deductions_on_owner_id"
  end

  create_table "credit_transactions", force: :cascade do |t|
    t.bigint "credit_wallet_id", null: false
    t.integer "transaction_type", null: false
    t.integer "amount", null: false
    t.integer "balance_after", null: false
    t.string "description"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["credit_wallet_id"], name: "index_credit_transactions_on_credit_wallet_id"
  end

  create_table "credit_wallets", force: :cascade do |t|
    t.integer "balance", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "owner_id", null: false
    t.index ["owner_id"], name: "index_credit_wallets_on_owner_id", unique: true
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

  create_table "email_deliveries", force: :cascade do |t|
    t.string "provider", default: "resend", null: false
    t.string "provider_message_id"
    t.string "mailer_name", null: false
    t.string "mailer_action", null: false
    t.string "recipient"
    t.jsonb "recipients", default: {}, null: false
    t.string "subject"
    t.string "status", default: "queued", null: false
    t.string "related_type"
    t.bigint "related_id"
    t.datetime "sent_at"
    t.datetime "delivered_at"
    t.datetime "failed_at"
    t.datetime "bounced_at"
    t.datetime "complained_at"
    t.datetime "suppressed_at"
    t.text "last_error"
    t.string "failure_reason"
    t.integer "retry_count", default: 0, null: false
    t.datetime "next_retry_at"
    t.bigint "resend_of_id"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_email_deliveries_on_created_at"
    t.index ["mailer_name", "mailer_action"], name: "index_email_deliveries_on_mailer_name_and_mailer_action"
    t.index ["provider_message_id"], name: "index_email_deliveries_on_provider_message_id", unique: true, where: "(provider_message_id IS NOT NULL)"
    t.index ["recipient"], name: "index_email_deliveries_on_recipient"
    t.index ["related_type", "related_id"], name: "index_email_deliveries_on_related"
    t.index ["resend_of_id"], name: "index_email_deliveries_on_resend_of_id"
    t.index ["status"], name: "index_email_deliveries_on_status"
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

  create_table "event_email_settings", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "sender_name"
    t.string "sender_address"
    t.string "contact_email"
    t.string "payment_receipt_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_email_settings_on_event_id", unique: true
  end

  create_table "event_exhibition_contractors", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "exhibition_contractor_profile_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_exhibition_contractors_on_event_id", unique: true
    t.index ["exhibition_contractor_profile_id"], name: "idx_on_exhibition_contractor_profile_id_13ae474f9f"
  end

  create_table "event_leads", force: :cascade do |t|
    t.bigint "event_vendor_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "leadable_type", null: false
    t.bigint "leadable_id", null: false
    t.text "notes"
    t.bigint "scanned_by_id"
    t.index ["event_vendor_id"], name: "index_event_leads_on_event_vendor_id"
    t.index ["leadable_type", "leadable_id", "event_vendor_id"], name: "index_event_leads_on_leadable_and_event_vendor", unique: true
    t.index ["leadable_type", "leadable_id"], name: "index_event_leads_on_leadable"
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

  create_table "event_payment_gateways", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "provider", default: "razorpay", null: false
    t.string "key_id", null: false
    t.text "key_secret", null: false
    t.text "webhook_secret"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "provider"], name: "index_event_payment_gateways_on_event_id_and_provider", unique: true
    t.index ["event_id"], name: "index_event_payment_gateways_on_event_id"
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

  create_table "event_reminder_logs", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "ticket_id", null: false
    t.string "reminder_type", null: false
    t.string "status", default: "sent"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "reminder_period_key"
    t.index ["event_id"], name: "index_event_reminder_logs_on_event_id"
    t.index ["ticket_id", "reminder_type", "reminder_period_key"], name: "index_event_reminder_logs_on_ticket_type_and_period", unique: true, where: "(reminder_period_key IS NOT NULL)"
    t.index ["ticket_id", "reminder_type"], name: "index_event_reminder_logs_on_ticket_and_type_when_period_null", unique: true, where: "(reminder_period_key IS NULL)"
    t.index ["ticket_id"], name: "index_event_reminder_logs_on_ticket_id"
    t.check_constraint "reminder_type::text = 'payment_pending_weekly'::text AND reminder_period_key::text = btrim(reminder_period_key::text) AND NULLIF(reminder_period_key::text, ''::text) IS NOT NULL OR (reminder_type::text = ANY (ARRAY['7_day'::character varying, '1_day'::character varying]::text[])) AND reminder_period_key IS NULL", name: "event_reminder_logs_type_period_key_match"
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

  create_table "event_seat_checkout_sessions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.bigint "event_seat_session_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_seat_session_id"], name: "index_event_seat_checkout_sessions_on_event_seat_session_id"
  end

  create_table "event_seat_group_assignments", force: :cascade do |t|
    t.bigint "event_seat_group_id", null: false
    t.bigint "event_ticket_seat_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_seat_group_id"], name: "idx_seat_group_assignment_on_group_id"
    t.index ["event_ticket_seat_id"], name: "idx_seat_group_assignment_on_seat_id"
    t.index ["event_ticket_seat_id"], name: "idx_unique_seat_assignment", unique: true
  end

  create_table "event_seat_groups", force: :cascade do |t|
    t.bigint "event_seat_section_id", null: false
    t.bigint "ticket_type_id"
    t.string "name", null: false
    t.decimal "extra_price", precision: 8, scale: 2, default: "0.0"
    t.string "color", default: "green"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_seat_section_id"], name: "index_event_seat_groups_on_event_seat_section_id"
    t.index ["ticket_type_id"], name: "index_event_seat_groups_on_ticket_type_id"
  end

  create_table "event_seat_sections", force: :cascade do |t|
    t.bigint "event_seat_venue_id", null: false
    t.string "name", null: false
    t.decimal "price", precision: 8, scale: 2, default: "0.0"
    t.integer "start_row"
    t.integer "start_column"
    t.integer "row_span"
    t.integer "col_span"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "seat_row", default: 1
    t.integer "seat_column", default: 1
    t.float "rotation", default: 0.0, null: false
    t.bigint "ticket_type_id"
    t.string "color", default: "blue"
    t.index ["event_seat_venue_id"], name: "index_event_seat_sections_on_event_seat_venue_id"
    t.index ["ticket_type_id"], name: "index_event_seat_sections_on_ticket_type_id"
  end

  create_table "event_seat_sessions", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.integer "status", default: 0, null: false
    t.string "location"
    t.integer "order", default: 0
    t.datetime "start_datetime"
    t.datetime "end_datetime"
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "public_id"
    t.string "slug"
    t.index ["deleted_at"], name: "index_event_seat_sessions_on_deleted_at"
    t.index ["event_id"], name: "index_event_seat_sessions_on_event_id"
    t.index ["public_id"], name: "index_event_seat_sessions_on_public_id", unique: true
    t.index ["slug"], name: "index_event_seat_sessions_on_slug", unique: true
  end

  create_table "event_seat_venues", force: :cascade do |t|
    t.bigint "event_seat_session_id", null: false
    t.string "name", null: false
    t.integer "total_row"
    t.integer "total_column"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "aspect_ratio"
    t.index ["event_seat_session_id"], name: "index_event_seat_venues_on_event_seat_session_id"
  end

  create_table "event_seating_group_members", force: :cascade do |t|
    t.bigint "event_seating_group_id", null: false
    t.string "participant_type", null: false
    t.bigint "participant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_seating_group_id", "participant_type"], name: "index_event_seating_group_members_on_group_and_type"
    t.index ["event_seating_group_id"], name: "index_event_seating_group_members_on_event_seating_group_id"
    t.index ["participant_type", "participant_id"], name: "index_event_seating_group_members_on_participant_unique", unique: true
  end

  create_table "event_seating_groups", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "plan_id"
    t.integer "scope", default: 0, null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "scope"], name: "index_event_seating_groups_on_event_id_and_scope"
    t.index ["event_id"], name: "index_event_seating_groups_on_event_id"
    t.index ["plan_id", "scope"], name: "index_event_seating_groups_on_plan_id_and_scope"
    t.index ["plan_id"], name: "index_event_seating_groups_on_plan_id"
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

  create_table "event_ticket_seats", force: :cascade do |t|
    t.bigint "event_seat_section_id", null: false
    t.string "name", null: false
    t.decimal "extra_price", precision: 8, scale: 2, default: "0.0"
    t.integer "row_set"
    t.integer "col_set"
    t.bigint "ticket_id"
    t.bigint "visitor_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "locked_by_session_id"
    t.bigint "ticket_type_id"
    t.index ["event_seat_section_id", "row_set", "col_set"], name: "idx_event_ticket_seats_on_section_coords", unique: true
    t.index ["event_seat_section_id"], name: "index_event_ticket_seats_on_event_seat_section_id"
    t.index ["locked_by_session_id"], name: "index_event_ticket_seats_on_locked_by_session_id"
    t.index ["ticket_id"], name: "index_event_ticket_seats_on_ticket_id"
    t.index ["ticket_type_id"], name: "index_event_ticket_seats_on_ticket_type_id"
    t.index ["visitor_id"], name: "index_event_ticket_seats_on_visitor_id"
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

  create_table "event_wish_wall_settings", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "display_mode", default: "cards", null: false
    t.string "animation_shape"
    t.string "animation_text"
    t.string "accent_color"
    t.string "header_text_color"
    t.string "card_background_color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_event_wish_wall_settings_on_event_id", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.string "title", null: false
    t.text "description"
    t.integer "status", default: 0, null: false
    t.boolean "multiple_scans", default: false, null: false
    t.datetime "start_date"
    t.datetime "end_date"
    t.text "webhook_url"
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
    t.boolean "use_seat_ticketing", default: false, null: false
    t.boolean "reminders_enabled", default: true
    t.boolean "reminder_7_day", default: true
    t.boolean "reminder_1_day", default: true
    t.jsonb "booth_types", default: []
    t.boolean "use_wedding", default: false, null: false
    t.integer "extra_guest_limit"
    t.boolean "auto_approve_wishes", default: false, null: false
    t.boolean "use_event_leads", default: false, null: false
    t.boolean "enable_exhibitor_management", default: false, null: false
    t.string "public_registration_url"
    t.string "venue_name"
    t.string "venue_address"
    t.boolean "use_voucher", default: true, null: false
    t.boolean "use_api_access", default: false, null: false
    t.boolean "use_certificate", default: false, null: false
    t.integer "exhibitor_reservation_ttl_hours"
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

  create_table "exhibitor_booth_price_tiers", force: :cascade do |t|
    t.bigint "exhibitor_booth_price_id", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "start_date", null: false
    t.datetime "end_date"
    t.string "label", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["exhibitor_booth_price_id", "start_date"], name: "idx_exhibitor_booth_price_tiers_on_booth_price_and_start"
    t.index ["exhibitor_booth_price_id"], name: "index_exhibitor_booth_price_tiers_on_exhibitor_booth_price_id"
    t.index ["start_date"], name: "index_exhibitor_booth_price_tiers_on_start_date"
  end

  create_table "exhibitor_booth_prices", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "booth_type", null: false
    t.string "label", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "exhibitor_zone_id"
    t.integer "quota"
    t.boolean "conferences_included", default: false, null: false
    t.index ["event_id", "booth_type", "exhibitor_zone_id", "label"], name: "idx_exhibitor_booth_prices_unique", unique: true
    t.index ["event_id"], name: "index_exhibitor_booth_prices_on_event_id"
    t.index ["exhibitor_zone_id"], name: "index_exhibitor_booth_prices_on_exhibitor_zone_id"
  end

  create_table "exhibitor_booths", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "exhibitor_booth_price_id", null: false
    t.bigint "exhibitor_kit_id"
    t.string "number", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "number"], name: "index_exhibitor_booths_on_event_id_and_number", unique: true
    t.index ["event_id"], name: "index_exhibitor_booths_on_event_id"
    t.index ["exhibitor_booth_price_id", "status"], name: "index_exhibitor_booths_on_exhibitor_booth_price_id_and_status"
    t.index ["exhibitor_booth_price_id"], name: "index_exhibitor_booths_on_exhibitor_booth_price_id"
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_booths_on_exhibitor_kit_id"
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
    t.string "country"
    t.string "pic_position"
    t.jsonb "custom_fields_data", default: {}, null: false
    t.bigint "exhibitor_booth_price_id"
    t.string "booth_type"
    t.integer "booth_quantity", default: 1, null: false
    t.string "public_id", default: -> { "(gen_random_uuid())::text" }, null: false
    t.string "idempotency_key"
    t.integer "booking_status", default: 0, null: false
    t.datetime "reservation_expires_at"
    t.decimal "price_snapshot", precision: 10, scale: 2, default: "0.0", null: false
    t.string "currency", default: "MYR", null: false
    t.integer "lock_version", default: 0, null: false
    t.bigint "exhibitor_package_id"
    t.index ["event_vendor_id", "idempotency_key"], name: "idx_exhibitor_kits_on_vendor_and_idempotency_key", unique: true, where: "(idempotency_key IS NOT NULL)"
    t.index ["event_vendor_id"], name: "index_exhibitor_kits_on_event_vendor_id"
    t.index ["exhibitor_booth_price_id"], name: "index_exhibitor_kits_on_exhibitor_booth_price_id"
    t.index ["exhibitor_package_id"], name: "index_exhibitor_kits_on_exhibitor_package_id"
    t.index ["public_id"], name: "index_exhibitor_kits_on_public_id", unique: true
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

  create_table "exhibitor_packages", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "exhibitor_booth_price_id", null: false
    t.string "name", null: false
    t.text "inclusions"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "quota"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "exhibitor_booth_price_id", "name"], name: "index_exhibitor_packages_on_event_booth_price_and_name", unique: true
    t.index ["event_id"], name: "index_exhibitor_packages_on_event_id"
    t.index ["exhibitor_booth_price_id"], name: "index_exhibitor_packages_on_exhibitor_booth_price_id"
  end

  create_table "exhibitor_registration_payments", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "status", default: "pending", null: false
    t.string "gateway"
    t.string "gateway_payment_id"
    t.string "payment_method"
    t.jsonb "gateway_response", default: {}, null: false
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "gateway_order_id"
    t.datetime "order_expires_at"
    t.string "currency", default: "MYR", null: false
    t.integer "lock_version", default: 0, null: false
    t.text "note"
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_registration_payments_on_exhibitor_kit_id", unique: true
    t.index ["gateway_order_id"], name: "index_exhibitor_registration_payments_on_gateway_order_id", unique: true, where: "(gateway_order_id IS NOT NULL)"
    t.index ["gateway_payment_id"], name: "index_exhibitor_registration_payments_on_gateway_payment_id", unique: true, where: "(gateway_payment_id IS NOT NULL)"
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
    t.string "gateway"
    t.string "gateway_payment_id"
    t.string "payment_method"
    t.jsonb "gateway_response", default: {}, null: false
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_team_member_payments_on_exhibitor_kit_id"
    t.index ["gateway_payment_id"], name: "index_exhibitor_team_member_payments_on_gateway_payment_id"
    t.index ["payee_id"], name: "index_exhibitor_team_member_payments_on_payee_id"
  end

  create_table "exhibitor_team_members", force: :cascade do |t|
    t.bigint "exhibitor_kit_id", null: false
    t.string "full_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "phone"
    t.string "attendee_type"
    t.bigint "attendee_id"
    t.index ["attendee_type", "attendee_id"], name: "index_exhibitor_team_members_on_attendee"
    t.index ["exhibitor_kit_id"], name: "index_exhibitor_team_members_on_exhibitor_kit_id"
  end

  create_table "exhibitor_vouchers", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "exhibitor_booth_price_id"
    t.bigint "exhibitor_package_id"
    t.string "code", null: false
    t.integer "discount_type", null: false
    t.decimal "discount_value", precision: 10, scale: 2, null: false
    t.integer "status", default: 0, null: false
    t.bigint "redeemed_by_exhibitor_kit_id"
    t.datetime "redeemed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_exhibitor_vouchers_on_code", unique: true
    t.index ["event_id"], name: "index_exhibitor_vouchers_on_event_id"
    t.index ["exhibitor_booth_price_id"], name: "index_exhibitor_vouchers_on_exhibitor_booth_price_id"
    t.index ["exhibitor_package_id"], name: "index_exhibitor_vouchers_on_exhibitor_package_id"
    t.index ["redeemed_by_exhibitor_kit_id"], name: "index_exhibitor_vouchers_on_redeemed_by_exhibitor_kit_id"
  end

  create_table "exhibitor_zones", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "zone", null: false
    t.integer "quota"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "zone"], name: "idx_exhibitor_zones_unique", unique: true
    t.index ["event_id"], name: "index_exhibitor_zones_on_event_id"
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

  create_table "pass_bundles", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "registration_form_id", null: false
    t.bigint "ticket_type_id", null: false
    t.bigint "created_by_id"
    t.string "name", null: false
    t.string "token", null: false
    t.integer "pass_limit", null: false
    t.integer "payment_mode", default: 0, null: false
    t.integer "payment_status", default: 0, null: false
    t.integer "status", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_pass_bundles_on_created_by_id"
    t.index ["event_id", "status"], name: "index_pass_bundles_on_event_id_and_status"
    t.index ["event_id", "token"], name: "index_pass_bundles_on_event_id_and_token", unique: true
    t.index ["event_id"], name: "index_pass_bundles_on_event_id"
    t.index ["registration_form_id"], name: "index_pass_bundles_on_registration_form_id"
    t.index ["ticket_type_id"], name: "index_pass_bundles_on_ticket_type_id"
    t.check_constraint "pass_limit >= 0", name: "chk_pass_bundles_pass_limit_non_negative"
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

  create_table "plan_objects", force: :cascade do |t|
    t.bigint "plan_id", null: false
    t.integer "object_type"
    t.string "layer"
    t.float "x"
    t.float "y"
    t.float "rotation", default: 0.0
    t.float "width"
    t.float "height"
    t.string "label"
    t.integer "capacity"
    t.boolean "locked", default: false
    t.integer "z_index", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "path"
    t.index ["plan_id"], name: "index_plan_objects_on_plan_id"
  end

  create_table "plans", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name"
    t.float "canvas_width", default: 0.0
    t.float "canvas_height", default: 0.0
    t.float "pixels_per_unit", default: 20.0
    t.boolean "public_enabled", default: false
    t.string "share_token"
    t.jsonb "settings_json"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_plans_on_event_id"
    t.index ["share_token"], name: "index_plans_on_share_token", unique: true
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

  create_table "public_exhibitor_access_sessions", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "normalized_email", null: false
    t.string "challenge_digest", null: false
    t.datetime "challenge_expires_at", null: false
    t.datetime "challenge_consumed_at"
    t.string "session_digest"
    t.datetime "expires_at"
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["challenge_digest"], name: "index_public_exhibitor_access_sessions_on_challenge_digest", unique: true
    t.index ["event_id", "normalized_email"], name: "idx_on_event_id_normalized_email_b1c25e2564"
    t.index ["event_id"], name: "index_public_exhibitor_access_sessions_on_event_id"
    t.index ["session_digest"], name: "index_public_exhibitor_access_sessions_on_session_digest", unique: true, where: "(session_digest IS NOT NULL)"
  end

  create_table "registration_form_rsvp_settings", force: :cascade do |t|
    t.bigint "registration_form_id", null: false
    t.boolean "enabled", default: false, null: false
    t.boolean "rsvp_required", default: false, null: false
    t.integer "rsvp_expires_in_hours"
    t.integer "review_sla_hours", default: 48, null: false
    t.datetime "notify_by_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["registration_form_id"], name: "index_registration_form_rsvp_settings_on_registration_form_id", unique: true
    t.check_constraint "review_sla_hours > 0", name: "chk_registration_form_rsvp_settings_review_sla_positive"
    t.check_constraint "rsvp_expires_in_hours IS NULL OR rsvp_expires_in_hours > 0", name: "chk_registration_form_rsvp_settings_expiry_positive"
  end

  create_table "registration_form_ticket_types", force: :cascade do |t|
    t.bigint "registration_form_id", null: false
    t.bigint "ticket_type_id", null: false
    t.integer "registration_mode", default: 0, null: false
    t.integer "min_attendees", default: 1, null: false
    t.integer "max_attendees"
    t.jsonb "custom_labels_data", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["registration_form_id", "ticket_type_id"], name: "idx_reg_form_ticket_types_unique", unique: true
    t.index ["registration_form_id"], name: "index_registration_form_ticket_types_on_registration_form_id"
    t.index ["ticket_type_id"], name: "index_registration_form_ticket_types_on_ticket_type_id"
    t.check_constraint "max_attendees IS NULL OR max_attendees >= min_attendees", name: "chk_reg_form_ticket_types_max_attendees"
    t.check_constraint "min_attendees >= 1", name: "chk_reg_form_ticket_types_min_attendees"
  end

  create_table "registration_forms", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "slug", null: false
    t.string "name", null: false
    t.text "description"
    t.jsonb "custom_labels_data", default: [], null: false
    t.integer "status", default: 0, null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "slug"], name: "index_registration_forms_on_event_id_and_slug", unique: true
    t.index ["event_id"], name: "index_registration_forms_on_event_id"
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
    t.bigint "resource_id", null: false
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

  create_table "roulette_assigns", force: :cascade do |t|
    t.bigint "roulette_session_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["roulette_session_id", "user_id"], name: "index_roulette_assigns_on_roulette_session_id_and_user_id", unique: true
    t.index ["roulette_session_id"], name: "index_roulette_assigns_on_roulette_session_id"
    t.index ["user_id"], name: "index_roulette_assigns_on_user_id"
  end

  create_table "roulette_prizes", force: :cascade do |t|
    t.bigint "roulette_session_id", null: false
    t.string "name", null: false
    t.integer "quantity", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["roulette_session_id", "created_at"], name: "index_roulette_prizes_on_roulette_session_id_and_created_at"
    t.index ["roulette_session_id"], name: "index_roulette_prizes_on_roulette_session_id"
  end

  create_table "roulette_sessions", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.date "draw_date"
    t.jsonb "draw_styles", default: {}
    t.jsonb "wrapper_background", default: {}
    t.boolean "is_multiple", default: false, null: false
    t.integer "draw_counts", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_roulette_sessions_on_created_at"
    t.index ["draw_date"], name: "index_roulette_sessions_on_draw_date"
    t.index ["draw_styles"], name: "index_roulette_sessions_on_draw_styles", using: :gin
    t.index ["event_id"], name: "index_roulette_sessions_on_event_id"
    t.index ["user_id"], name: "index_roulette_sessions_on_user_id"
    t.index ["wrapper_background"], name: "index_roulette_sessions_on_wrapper_background", using: :gin
  end

  create_table "roulette_winners", force: :cascade do |t|
    t.bigint "roulette_session_id", null: false
    t.bigint "roulette_prize_id", null: false
    t.bigint "ticket_id"
    t.bigint "visitor_id"
    t.datetime "drawn_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["roulette_prize_id"], name: "index_roulette_winners_on_roulette_prize_id"
    t.index ["roulette_session_id"], name: "index_roulette_winners_on_roulette_session_id"
    t.index ["ticket_id"], name: "index_roulette_winners_on_ticket_id"
    t.index ["visitor_id"], name: "index_roulette_winners_on_visitor_id"
    t.check_constraint "ticket_id IS NOT NULL AND visitor_id IS NULL OR ticket_id IS NULL AND visitor_id IS NOT NULL", name: "roulette_winners_exactly_one_participant"
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

  create_table "table_assignments", force: :cascade do |t|
    t.bigint "ticket_id"
    t.bigint "plan_object_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "visitor_id"
    t.text "notes"
    t.datetime "arrived_at"
    t.index ["plan_object_id"], name: "index_table_assignments_on_plan_object_id"
    t.index ["ticket_id"], name: "index_table_assignments_on_ticket_id"
    t.index ["visitor_id"], name: "index_table_assignments_on_visitor_id"
    t.check_constraint "ticket_id IS NOT NULL AND visitor_id IS NULL OR ticket_id IS NULL AND visitor_id IS NOT NULL", name: "table_assignments_exactly_one_participant"
  end

  create_table "ticket_applications", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.bigint "registration_form_id", null: false
    t.integer "review_status", default: 0, null: false
    t.integer "rsvp_status", default: 0, null: false
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "rejection_reason"
    t.string "rsvp_token_digest"
    t.datetime "rsvp_sent_at"
    t.datetime "rsvp_confirmed_at"
    t.datetime "rsvp_expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["registration_form_id"], name: "index_ticket_applications_on_registration_form_id"
    t.index ["reviewed_by_id"], name: "index_ticket_applications_on_reviewed_by_id"
    t.index ["rsvp_token_digest"], name: "index_ticket_applications_on_rsvp_token_digest", unique: true
    t.index ["ticket_id"], name: "index_ticket_applications_on_ticket_id", unique: true
    t.check_constraint "review_status = ANY (ARRAY[0, 1, 2])", name: "chk_ticket_applications_review_status"
    t.check_constraint "rsvp_status = ANY (ARRAY[0, 1, 2, 3, 4])", name: "chk_ticket_applications_rsvp_status"
  end

  create_table "ticket_payments", force: :cascade do |t|
    t.bigint "ticket_id", null: false
    t.bigint "received_by_id"
    t.string "gateway"
    t.string "gateway_payment_id"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.string "currency", default: "MYR"
    t.string "status", default: "pending"
    t.string "payment_method"
    t.json "gateway_response", default: {}
    t.text "notes"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_screenshot_url"
    t.index ["gateway_payment_id"], name: "index_ticket_payments_on_gateway_payment_id"
    t.index ["received_by_id"], name: "index_ticket_payments_on_received_by_id"
    t.index ["ticket_id", "gateway"], name: "index_ticket_payments_on_ticket_id_and_gateway", unique: true, where: "(gateway IS NOT NULL)"
    t.index ["ticket_id"], name: "index_ticket_payments_on_ticket_id"
  end

  create_table "ticket_type_price_tiers", force: :cascade do |t|
    t.bigint "ticket_type_id", null: false
    t.string "label", null: false
    t.decimal "price", precision: 10, scale: 2, null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ticket_type_id", "starts_at"], name: "idx_price_tiers_on_ticket_type_and_start"
    t.index ["ticket_type_id"], name: "index_ticket_type_price_tiers_on_ticket_type_id"
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
    t.integer "seat_ticketing_type"
    t.bigint "seat_ticketing_source_id"
    t.index ["event_id", "status"], name: "index_ticket_types_on_event_id_and_status"
    t.index ["event_id"], name: "index_ticket_types_on_event_id"
    t.index ["seat_ticketing_type", "seat_ticketing_source_id"], name: "idx_ticket_types_on_seat_ticketing"
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
    t.jsonb "custom_fields_data", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "attendee_email_norm"
    t.string "attendee_phone_norm"
    t.string "attendee_name_norm"
    t.datetime "deleted_at"
    t.string "role"
    t.string "registered_by_email"
    t.bigint "pass_bundle_id"
    t.bigint "vehicle_registration_id"
    t.boolean "waiting_list", default: false, null: false
    t.index "event_id, lower((custom_fields_data ->> 'ic_passport_no'::text))", name: "idx_tickets_unique_ic_passport_no", unique: true, where: "((deleted_at IS NULL) AND (status <> 3) AND (NULLIF((custom_fields_data ->> 'ic_passport_no'::text), ''::text) IS NOT NULL))"
    t.index "event_id, lower((custom_fields_data ->> 'membership_no'::text))", name: "idx_tickets_unique_membership_no", unique: true, where: "((deleted_at IS NULL) AND (status <> 3) AND (NULLIF((custom_fields_data ->> 'membership_no'::text), ''::text) IS NOT NULL))"
    t.index ["deleted_at"], name: "index_tickets_on_deleted_at"
    t.index ["event_id", "attendee_email_norm"], name: "idx_tickets_event_email_norm", where: "(attendee_email_norm IS NOT NULL)"
    t.index ["event_id", "attendee_phone_norm"], name: "idx_tickets_event_phone_norm", where: "(attendee_phone_norm IS NOT NULL)"
    t.index ["event_id", "registered_by_email"], name: "idx_tickets_event_registered_by_email", where: "(registered_by_email IS NOT NULL)"
    t.index ["event_id", "status"], name: "index_tickets_on_event_id_and_status"
    t.index ["event_id", "ticket_type_id", "attendee_name_norm"], name: "idx_tickets_event_type_name_norm_unique", unique: true, where: "((attendee_email_norm IS NULL) AND (attendee_phone_norm IS NULL))"
    t.index ["event_id"], name: "index_tickets_on_event_id"
    t.index ["pass_bundle_id"], name: "index_tickets_on_pass_bundle_id"
    t.index ["public_id"], name: "index_tickets_on_public_id", unique: true
    t.index ["scanned_by_id"], name: "index_tickets_on_scanned_by_id"
    t.index ["ticket_type_id"], name: "index_tickets_on_ticket_type_id"
    t.index ["user_id"], name: "index_tickets_on_user_id"
    t.index ["vehicle_registration_id"], name: "index_tickets_on_vehicle_registration_id"
    t.index ["waiting_list"], name: "index_tickets_on_waiting_list"
  end

  create_table "user_sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "jti", null: false
    t.string "refresh_token_hash", null: false
    t.string "device_name"
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_used_at"
    t.datetime "expires_at", null: false
    t.boolean "revoked", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_user_sessions_on_expires_at"
    t.index ["jti"], name: "index_user_sessions_on_jti", unique: true
    t.index ["last_used_at"], name: "index_user_sessions_on_last_used_at"
    t.index ["refresh_token_hash"], name: "index_user_sessions_on_refresh_token_hash", unique: true
    t.index ["user_id", "revoked"], name: "index_user_sessions_on_user_id_and_revoked"
    t.index ["user_id"], name: "index_user_sessions_on_user_id"
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

  create_table "vehicle_registrations", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "registration_form_id", null: false
    t.bigint "base_ticket_type_id", null: false
    t.string "plate", null: false
    t.string "normalized_plate", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["base_ticket_type_id"], name: "index_vehicle_registrations_on_base_ticket_type_id"
    t.index ["event_id", "normalized_plate"], name: "idx_vehicle_registrations_event_plate", unique: true
    t.index ["event_id"], name: "index_vehicle_registrations_on_event_id"
    t.index ["registration_form_id"], name: "index_vehicle_registrations_on_registration_form_id"
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
    t.integer "rsvp_status", default: 0
    t.datetime "rsvp_responded_at"
    t.bigint "added_by_id"
    t.index ["added_by_id"], name: "index_visitors_on_added_by_id"
    t.index ["event_id"], name: "index_visitors_on_event_id"
    t.index ["public_id"], name: "index_visitors_on_public_id", unique: true
    t.index ["rsvp_status"], name: "index_visitors_on_rsvp_status"
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

  create_table "wishes", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "visitor_id"
    t.string "guest_name", null: false
    t.text "message", null: false
    t.integer "status", default: 0, null: false
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "status"], name: "index_wishes_on_event_id_and_status"
    t.index ["event_id"], name: "index_wishes_on_event_id"
    t.index ["visitor_id"], name: "index_wishes_on_visitor_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "api_keys", "events"
  add_foreign_key "api_keys", "users"
  add_foreign_key "business_host_assignments", "events"
  add_foreign_key "business_host_assignments", "users"
  add_foreign_key "business_matching_availabilities", "business_matching_participants"
  add_foreign_key "business_matching_availabilities", "business_matching_sessions"
  add_foreign_key "business_matching_availabilities", "users", column: "host_user_id"
  add_foreign_key "business_matching_bookings", "business_matching_participants", column: "receiver_participant_id"
  add_foreign_key "business_matching_bookings", "business_matching_participants", column: "requester_participant_id"
  add_foreign_key "business_matching_bookings", "business_matching_sessions"
  add_foreign_key "business_matching_bookings", "users", column: "host_user_id"
  add_foreign_key "business_matching_participants", "events"
  add_foreign_key "business_matching_sessions", "events"
  add_foreign_key "certificate_templates", "events"
  add_foreign_key "check_in_displays", "events"
  add_foreign_key "check_in_displays", "plans", column: "active_plan_id"
  add_foreign_key "cloned_voices", "events"
  add_foreign_key "cloned_voices", "users", column: "creator_id"
  add_foreign_key "cloned_voices", "users", column: "owner_id"
  add_foreign_key "credit_deductions", "events"
  add_foreign_key "credit_deductions", "users", column: "owner_id"
  add_foreign_key "credit_transactions", "credit_wallets"
  add_foreign_key "credit_wallets", "users", column: "owner_id"
  add_foreign_key "custom_requests", "exhibitor_kits"
  add_foreign_key "email_deliveries", "email_deliveries", column: "resend_of_id"
  add_foreign_key "email_verifications", "users"
  add_foreign_key "event_assignments", "events"
  add_foreign_key "event_assignments", "users"
  add_foreign_key "event_email_settings", "events"
  add_foreign_key "event_exhibition_contractors", "events"
  add_foreign_key "event_exhibition_contractors", "exhibition_contractor_profiles"
  add_foreign_key "event_leads", "event_vendors"
  add_foreign_key "event_leads", "users", column: "scanned_by_id", on_delete: :nullify
  add_foreign_key "event_location_members", "event_locations"
  add_foreign_key "event_location_members", "users", column: "member_id"
  add_foreign_key "event_locations", "events"
  add_foreign_key "event_payment_gateways", "events"
  add_foreign_key "event_printing_service_price_tiers", "event_printing_services"
  add_foreign_key "event_printing_services", "events"
  add_foreign_key "event_printing_services", "printing_services"
  add_foreign_key "event_reminder_logs", "events"
  add_foreign_key "event_reminder_logs", "tickets"
  add_foreign_key "event_rentable_item_price_tiers", "event_rentable_items"
  add_foreign_key "event_rentable_items", "events"
  add_foreign_key "event_rentable_items", "rentable_items"
  add_foreign_key "event_seat_checkout_sessions", "event_seat_sessions"
  add_foreign_key "event_seat_group_assignments", "event_seat_groups"
  add_foreign_key "event_seat_group_assignments", "event_ticket_seats"
  add_foreign_key "event_seat_groups", "event_seat_sections"
  add_foreign_key "event_seat_groups", "ticket_types"
  add_foreign_key "event_seat_sections", "event_seat_venues"
  add_foreign_key "event_seat_sections", "ticket_types"
  add_foreign_key "event_seat_sessions", "events"
  add_foreign_key "event_seat_venues", "event_seat_sessions"
  add_foreign_key "event_seating_group_members", "event_seating_groups"
  add_foreign_key "event_seating_groups", "events"
  add_foreign_key "event_seating_groups", "plans"
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
  add_foreign_key "event_ticket_seats", "event_seat_checkout_sessions", column: "locked_by_session_id"
  add_foreign_key "event_ticket_seats", "event_seat_sections"
  add_foreign_key "event_ticket_seats", "ticket_types"
  add_foreign_key "event_ticket_seats", "tickets"
  add_foreign_key "event_ticket_seats", "visitors"
  add_foreign_key "event_vendors", "events"
  add_foreign_key "event_vendors", "exhibitor_owners"
  add_foreign_key "event_vendors", "users", column: "vendor_id"
  add_foreign_key "event_wish_wall_settings", "events"
  add_foreign_key "exhibition_contractor_profiles", "users"
  add_foreign_key "exhibitor_booth_price_tiers", "exhibitor_booth_prices"
  add_foreign_key "exhibitor_booth_prices", "events"
  add_foreign_key "exhibitor_booth_prices", "exhibitor_zones"
  add_foreign_key "exhibitor_booths", "events"
  add_foreign_key "exhibitor_booths", "exhibitor_booth_prices"
  add_foreign_key "exhibitor_booths", "exhibitor_kits"
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
  add_foreign_key "exhibitor_kits", "exhibitor_booth_prices"
  add_foreign_key "exhibitor_kits", "exhibitor_packages"
  add_foreign_key "exhibitor_packages", "events"
  add_foreign_key "exhibitor_packages", "exhibitor_booth_prices"
  add_foreign_key "exhibitor_registration_payments", "exhibitor_kits"
  add_foreign_key "exhibitor_team_member_limits", "events"
  add_foreign_key "exhibitor_team_member_payments", "exhibitor_kits"
  add_foreign_key "exhibitor_team_member_payments", "users", column: "payee_id"
  add_foreign_key "exhibitor_team_members", "exhibitor_kits"
  add_foreign_key "exhibitor_vouchers", "events"
  add_foreign_key "exhibitor_vouchers", "exhibitor_booth_prices"
  add_foreign_key "exhibitor_vouchers", "exhibitor_kits", column: "redeemed_by_exhibitor_kit_id", on_delete: :nullify
  add_foreign_key "exhibitor_vouchers", "exhibitor_packages"
  add_foreign_key "exhibitor_zones", "events"
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
  add_foreign_key "pass_bundles", "events"
  add_foreign_key "pass_bundles", "registration_forms"
  add_foreign_key "pass_bundles", "ticket_types"
  add_foreign_key "pass_bundles", "users", column: "created_by_id"
  add_foreign_key "password_resets", "users"
  add_foreign_key "payment_details", "users"
  add_foreign_key "plan_objects", "plans"
  add_foreign_key "plans", "events"
  add_foreign_key "printing_services", "item_categories"
  add_foreign_key "printing_services", "users"
  add_foreign_key "public_exhibitor_access_sessions", "events"
  add_foreign_key "registration_form_rsvp_settings", "registration_forms"
  add_foreign_key "registration_form_ticket_types", "registration_forms"
  add_foreign_key "registration_form_ticket_types", "ticket_types"
  add_foreign_key "registration_forms", "events"
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
  add_foreign_key "roulette_assigns", "roulette_sessions"
  add_foreign_key "roulette_assigns", "users"
  add_foreign_key "roulette_prizes", "roulette_sessions"
  add_foreign_key "roulette_sessions", "events"
  add_foreign_key "roulette_sessions", "users"
  add_foreign_key "roulette_winners", "roulette_prizes"
  add_foreign_key "roulette_winners", "roulette_sessions"
  add_foreign_key "roulette_winners", "tickets", on_delete: :cascade
  add_foreign_key "roulette_winners", "visitors", on_delete: :cascade
  add_foreign_key "sponsors", "groups"
  add_foreign_key "sponsors", "users", column: "created_by_id"
  add_foreign_key "table_assignments", "plan_objects"
  add_foreign_key "table_assignments", "tickets"
  add_foreign_key "table_assignments", "visitors"
  add_foreign_key "ticket_applications", "registration_forms"
  add_foreign_key "ticket_applications", "tickets"
  add_foreign_key "ticket_applications", "users", column: "reviewed_by_id"
  add_foreign_key "ticket_payments", "tickets"
  add_foreign_key "ticket_payments", "users", column: "received_by_id"
  add_foreign_key "ticket_type_price_tiers", "ticket_types"
  add_foreign_key "ticket_types", "events"
  add_foreign_key "tickets", "events"
  add_foreign_key "tickets", "pass_bundles"
  add_foreign_key "tickets", "ticket_types"
  add_foreign_key "tickets", "users"
  add_foreign_key "tickets", "users", column: "scanned_by_id"
  add_foreign_key "tickets", "vehicle_registrations"
  add_foreign_key "user_sessions", "users"
  add_foreign_key "users", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "vehicle_registrations", "events"
  add_foreign_key "vehicle_registrations", "registration_forms"
  add_foreign_key "vehicle_registrations", "ticket_types", column: "base_ticket_type_id"
  add_foreign_key "vendor_profiles", "users", column: "vendor_id"
  add_foreign_key "visitors", "events"
  add_foreign_key "visitors", "users", column: "scanned_by_id"
  add_foreign_key "visitors", "visitors", column: "added_by_id"
  add_foreign_key "voucher_redemption_logs", "users", column: "redeemer_staff_id"
  add_foreign_key "voucher_redemption_logs", "vouchers"
  add_foreign_key "voucher_usages", "vouchers"
  add_foreign_key "vouchers", "events"
  add_foreign_key "vouchers", "users", column: "vendor_id"
  add_foreign_key "wishes", "events"
  add_foreign_key "wishes", "visitors"
end
