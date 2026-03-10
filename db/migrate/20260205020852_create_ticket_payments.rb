class CreateTicketPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :ticket_payments do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :received_by, foreign_key: { to_table: :users }, null: true
      t.string :gateway
      t.string :gateway_payment_id
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :currency, default: "MYR"
      t.string :status, default: "pending"
      t.string :payment_method
      t.json :gateway_response, default: {}
      t.text :notes
      t.datetime :paid_at
      t.timestamps
    end

    add_index :ticket_payments, :gateway_payment_id
    add_index :ticket_payments, [:ticket_id, :gateway], unique: true, where: "gateway IS NOT NULL"
  end
end
