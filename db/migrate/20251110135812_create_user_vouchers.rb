class CreateUserVouchers < ActiveRecord::Migration[8.0]
  def change
    create_table :user_vouchers do |t|
      # Associations
      t.references :ticket, null: false, foreign_key: true
      t.references :voucher, null: false, foreign_key: true

      # Timestamps for tracking voucher usage
      t.timestamp :claimed_at
      t.timestamp :used_at
    end

    # Add unique index to prevent duplicate ticket-voucher associations
    add_index :user_vouchers, [:ticket_id, :voucher_id], unique: true
  end
end
