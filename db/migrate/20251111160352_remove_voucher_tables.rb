class RemoveVoucherTables < ActiveRecord::Migration[8.0]
  def up
    # Drop user_vouchers table first (due to foreign keys)
    if table_exists?(:user_vouchers)
      drop_table :user_vouchers do |t|
        t.references :ticket, null: false, foreign_key: true
        t.references :voucher, null: false, foreign_key: true
        t.timestamp :claimed_at
        t.timestamp :used_at
      end
    end

    # Drop vouchers table
    if table_exists?(:vouchers)
      drop_table :vouchers do |t|
        t.string :name, null: false
        t.boolean :active_status, default: true, null: false
        t.uuid :public_id, null: false
        t.jsonb :rules
        t.timestamp :valid_until
        t.references :event, null: false, foreign_key: true
        t.references :vendor, null: false, foreign_key: { to_table: :users }
        t.timestamp :deleted_at
        t.timestamps
      end
    end
  end

  def down
    # Recreate vouchers table
    create_table :vouchers do |t|
      t.string :name, null: false
      t.boolean :active_status, default: true, null: false
      t.uuid :public_id, null: false
      t.jsonb :rules
      t.timestamp :valid_until
      t.references :event, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: { to_table: :users }
      t.timestamp :deleted_at
      t.timestamps
    end

    add_index :vouchers, :public_id, unique: true
    add_index :vouchers, [:event_id, :vendor_id]

    # Recreate user_vouchers table
    create_table :user_vouchers do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :voucher, null: false, foreign_key: true
      t.timestamp :claimed_at
      t.timestamp :used_at
      t.timestamps
    end

    add_index :user_vouchers, [:ticket_id, :voucher_id], unique: true
    add_index :user_vouchers, :ticket_id
    add_index :user_vouchers, :voucher_id
  end
end
