class CreateBusinessMatchingReminderLogs < ActiveRecord::Migration[8.0]
  def change
    # business_matching_bookings uses a uuid primary key, which the shared
    # EmailDelivery.related_id (bigint) polymorphic column can't represent —
    # so reminder dedupe for this feature needs its own log table, same
    # shape as EventReminderLog.
    create_table :business_matching_reminder_logs do |t|
      t.uuid :business_matching_booking_id, null: false
      t.string :reminder_type, null: false, default: "1_hour"
      t.string :status, default: "sent"
      t.datetime :sent_at
      t.timestamps
    end

    add_foreign_key :business_matching_reminder_logs, :business_matching_bookings
    add_index :business_matching_reminder_logs, %i[business_matching_booking_id reminder_type],
              unique: true, name: "index_bm_reminder_logs_on_booking_and_type"
  end
end
