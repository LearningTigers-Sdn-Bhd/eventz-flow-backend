class CreateVouchers < ActiveRecord::Migration[8.0]
  def change
    create_table :vouchers do |t|
      t.string :title
      t.uuid :voucher_uuid, default: 'gen_random_uuid()', null: false
      t.text :description
      t.references :vendor, foreign_key: { to_table: :users }
      t.references :event, foreign_key: true
      t.string :voucher_code
      t.string :status
      t.date :start_date
      t.date :end_date
      t.time :start_time
      t.time :end_time
      t.integer :total_redemption_available
      t.integer :redeemed_count
      t.integer :max_redemptions_per_user
      t.text :user_role_restriction
      t.string :voucher_type
      t.decimal :voucher_value, precision: 10, scale: 2
      t.timestamps
    end
    add_index :vouchers, :voucher_code
    add_index :vouchers, :status
  end
end
