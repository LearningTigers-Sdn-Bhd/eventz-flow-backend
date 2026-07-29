class HardenExhibitorRegistrationPayments < ActiveRecord::Migration[8.0]
  def up
    add_column :exhibitor_registration_payments, :gateway_order_id, :string
    add_column :exhibitor_registration_payments, :order_expires_at, :datetime
    add_column :exhibitor_registration_payments, :currency, :string, default: 'MYR', null: false
    add_column :exhibitor_registration_payments, :lock_version, :integer, default: 0, null: false

    execute <<~SQL.squish
      UPDATE exhibitor_registration_payments
      SET gateway_order_id = COALESCE(gateway_response->>'order_id', gateway_response->>'id')
      WHERE gateway_order_id IS NULL
        AND COALESCE(gateway_response->>'order_id', gateway_response->>'id') LIKE 'order_%'
    SQL

    add_index :exhibitor_registration_payments, :gateway_order_id, unique: true,
      where: 'gateway_order_id IS NOT NULL'
    remove_index :exhibitor_registration_payments, :gateway_payment_id
    add_index :exhibitor_registration_payments, :gateway_payment_id, unique: true,
      where: 'gateway_payment_id IS NOT NULL'
  end

  def down
    remove_index :exhibitor_registration_payments, :gateway_payment_id
    add_index :exhibitor_registration_payments, :gateway_payment_id
    remove_index :exhibitor_registration_payments, :gateway_order_id
    remove_columns :exhibitor_registration_payments, :gateway_order_id, :order_expires_at, :currency, :lock_version
  end
end
