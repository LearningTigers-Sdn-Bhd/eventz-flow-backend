class RemovePaymentColumnsFromTickets < ActiveRecord::Migration[8.0]
  def change
    # Remove columns that are now tracked in ticket_payments table
    # KEEP: payment_status (for quick filtering, synced from ticket_payments)
    remove_column :tickets, :payment_method, :string
    remove_column :tickets, :transaction_id, :string
    remove_column :tickets, :payment_screenshot_url, :string
  end
end
