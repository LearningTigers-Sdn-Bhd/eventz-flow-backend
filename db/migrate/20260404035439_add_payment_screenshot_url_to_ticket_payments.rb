class AddPaymentScreenshotUrlToTicketPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :ticket_payments, :payment_screenshot_url, :string
  end
end
