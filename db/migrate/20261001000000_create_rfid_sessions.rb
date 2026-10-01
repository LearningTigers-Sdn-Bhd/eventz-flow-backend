# Timed sessions (talks) staff define per event. Attendance is derived from the
# gate visits that overlap a session's window; nothing is scanned per session.
class CreateRfidSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :rfid_sessions do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      # Every session counts toward the e-certificate unless staff untick it.
      t.boolean :mandatory, null: false, default: true
      t.timestamps
    end
    add_index :rfid_sessions, %i[event_id starts_at]

    # Share of a session's length a guest must be inside to count as attended.
    add_column :events, :rfid_attendance_percent, :integer, null: false, default: 80
  end
end
