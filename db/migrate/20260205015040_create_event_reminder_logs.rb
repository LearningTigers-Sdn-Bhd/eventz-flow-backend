class CreateEventReminderLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :event_reminder_logs do |t|
      t.references :event, null: false, foreign_key: true
      t.references :ticket, null: false, foreign_key: true
      t.string :reminder_type, null: false
      t.string :status, default: "sent"
      t.datetime :sent_at
      t.timestamps
    end

    add_index :event_reminder_logs, [:ticket_id, :reminder_type], unique: true
  end
end
