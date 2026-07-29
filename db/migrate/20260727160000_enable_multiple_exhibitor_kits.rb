class EnableMultipleExhibitorKits < ActiveRecord::Migration[8.0]
  def up
    add_column :exhibitor_kits, :public_id, :uuid, default: -> { 'gen_random_uuid()' }
    add_column :exhibitor_kits, :idempotency_key, :string
    add_column :exhibitor_kits, :booking_status, :integer, default: 0
    add_column :exhibitor_kits, :reservation_expires_at, :datetime
    add_column :exhibitor_kits, :price_snapshot, :decimal, precision: 10, scale: 2, default: 0
    add_column :exhibitor_kits, :currency, :string, default: 'MYR'
    add_column :exhibitor_kits, :lock_version, :integer, default: 0, null: false

    execute <<~SQL.squish
      UPDATE exhibitor_kits
      SET public_id = COALESCE(public_id, gen_random_uuid()),
          booking_status = CASE WHEN payment_status IN (1, 2, 3) THEN 1 ELSE 0 END,
          price_snapshot = COALESCE(
            amount_paid,
            (SELECT price FROM exhibitor_booth_prices WHERE id = exhibitor_kits.exhibitor_booth_price_id),
            0
          ),
          currency = 'MYR'
    SQL

    change_column_null :exhibitor_kits, :public_id, false
    change_column_null :exhibitor_kits, :booking_status, false
    change_column_null :exhibitor_kits, :price_snapshot, false
    change_column_null :exhibitor_kits, :currency, false

    add_index :exhibitor_kits, :public_id, unique: true
    add_index :exhibitor_kits, %i[event_vendor_id idempotency_key], unique: true,
      where: 'idempotency_key IS NOT NULL', name: 'idx_exhibitor_kits_on_vendor_and_idempotency_key'
  end

  def down
    remove_index :exhibitor_kits, name: 'idx_exhibitor_kits_on_vendor_and_idempotency_key'
    remove_index :exhibitor_kits, :public_id
    remove_columns :exhibitor_kits, :public_id, :idempotency_key, :booking_status,
      :reservation_expires_at, :price_snapshot, :currency, :lock_version
  end
end
