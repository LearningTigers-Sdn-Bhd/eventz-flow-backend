class AddPaymentReceiptEmailToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :payment_receipt_email, :string
  end
end
