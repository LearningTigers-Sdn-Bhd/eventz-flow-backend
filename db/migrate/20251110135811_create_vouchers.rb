class CreateVouchers < ActiveRecord::Migration[8.0]
  def change
    create_table :vouchers do |t|
      # Associations
      t.references :event, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: { to_table: :users }

      # Core Voucher Details
      t.string :name, null: false
      t.boolean :active_status, null: false, default: true
      t.uuid :public_id, null: false, default: 'gen_random_uuid()'

      # Optional Fields
      t.jsonb :rules, default: {}
      t.timestamp :valid_until

      # Soft Delete
      t.timestamp :deleted_at

      t.timestamps
    end

    # Add unique index on public_id for QR code scanning
    add_index :vouchers, :public_id, unique: true

    # Add composite index for efficient lookups by event and vendor
    add_index :vouchers, [:event_id, :vendor_id]

    # Add index on deleted_at for soft delete queries
    add_index :vouchers, :deleted_at
  end
end
