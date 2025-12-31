class CreatePaymentDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :payment_details do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :bank_name, null: false
      t.string :account_number, null: false
      t.string :account_name, null: false

      t.timestamps
    end
  end
end
