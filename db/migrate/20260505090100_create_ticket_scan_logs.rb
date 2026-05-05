class CreateTicketScanLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_scan_logs do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.integer :day_index, null: false
      t.datetime :scanned_at, null: false
      t.references :scanned_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :ticket_scan_logs, [:ticket_id, :day_index], unique: true
    add_index :ticket_scan_logs, [:event_id, :scanned_at]
    add_index :ticket_scan_logs, [:scanned_by_id, :scanned_at]
  end
end
