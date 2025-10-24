class AddPaymentFieldsToTickets < ActiveRecord::Migration[8.0]
  def change
    add_column :tickets, :payment_screenshot_url, :string
    add_column :tickets, :transaction_id, :string
    add_column :tickets, :payment_method, :string
  end
end
