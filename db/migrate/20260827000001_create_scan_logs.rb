class CreateScanLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :scan_logs do |t|
      t.references :event, null: false, foreign_key: true
      t.string :scannable_type, null: false
      t.bigint :scannable_id, null: false
      t.references :event_location, null: true, foreign_key: true
      t.bigint :scanned_by_id
      t.datetime :scanned_at, null: false
      t.integer :source, null: false, default: 0

      t.timestamps
    end

    add_index :scan_logs, %i[event_id scanned_at]
    add_index :scan_logs, %i[scannable_type scannable_id scanned_at],
              name: 'idx_scan_logs_on_scannable'
    add_foreign_key :scan_logs, :users, column: :scanned_by_id
  end
end
