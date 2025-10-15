class AddPaymentStatusAndPriceToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :payment_status, :integer, default: 0
    add_column :events, :price, :decimal, precision: 8, scale: 2, default: 0
  end
end
