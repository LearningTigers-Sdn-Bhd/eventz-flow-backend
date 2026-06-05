class AddUseVoucherToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :use_voucher, :boolean, default: true, null: false
  end
end
