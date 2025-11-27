class AddIsUnlimitedToVouchers < ActiveRecord::Migration[7.0]
  def change
    add_column :vouchers, :is_unlimited, :boolean, default: false, null: false
  end
end
