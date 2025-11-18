class CreateVoucherRedemptionLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :voucher_redemption_logs do |t|
      t.references :voucher, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :redeemer_staff, foreign_key: { to_table: :users }
      t.datetime :redemption_timestamp
      t.string :redemption_location
      t.string :redemption_status
      t.decimal :transaction_gross_amount, precision: 10, scale: 2
      t.decimal :discount_applied_value, precision: 10, scale: 2
      t.decimal :transaction_net_amount, precision: 10, scale: 2
      t.datetime :cancellation_timestamp
      t.text :cancellation_reason
      t.text :notes

      t.timestamps
    end
  end
end
