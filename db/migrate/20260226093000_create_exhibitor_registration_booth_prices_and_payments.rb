class CreateExhibitorRegistrationBoothPricesAndPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_booth_prices do |t|
      t.references :event, null: false, foreign_key: true
      t.string :booth_type, null: false
      t.string :label, null: false
      t.decimal :price, precision: 10, scale: 2, null: false

      t.timestamps
    end

    add_index :exhibitor_booth_prices, [:event_id, :booth_type, :label], unique: true, name: "idx_exhibitor_booth_prices_unique"

    add_column :exhibitor_kits, :country, :string
    add_column :exhibitor_kits, :pic_position, :string
    add_column :exhibitor_kits, :custom_fields_data, :jsonb, default: {}, null: false
    add_reference :exhibitor_kits, :exhibitor_booth_price, foreign_key: true

    create_table :exhibitor_registration_payments do |t|
      t.references :exhibitor_kit, null: false, foreign_key: true, index: { unique: true }
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :status, null: false, default: "pending"
      t.string :gateway
      t.string :gateway_payment_id
      t.string :payment_method
      t.jsonb :gateway_response, default: {}, null: false
      t.datetime :paid_at

      t.timestamps
    end

    add_index :exhibitor_registration_payments, :gateway_payment_id
  end
end
