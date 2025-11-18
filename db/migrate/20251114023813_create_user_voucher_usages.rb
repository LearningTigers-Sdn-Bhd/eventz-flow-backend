class CreateUserVoucherUsages < ActiveRecord::Migration[8.0]
  def change
    create_table :user_voucher_usages do |t|
      t.references :voucher, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :redemption_count
      t.datetime :first_view_timestamp

      t.timestamps
    end
  end
end
