class UpdateVoucherColumns < ActiveRecord::Migration[8.0]
  def change
    add_column :vouchers, :voucher_category, :string
    
    remove_column :vouchers, :status, :string
    add_column :vouchers, :status, :integer, default: 0
    add_index :vouchers, :status

    remove_column :vouchers, :voucher_type, :string
    add_column :vouchers, :voucher_type, :integer
  end
end
