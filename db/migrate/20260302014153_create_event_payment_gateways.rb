class CreateEventPaymentGateways < ActiveRecord::Migration[8.0]
  def change
    create_table :event_payment_gateways do |t|
      t.references :event, null: false, foreign_key: true
      t.string :provider, null: false, default: 'razorpay'
      t.string :key_id, null: false
      t.text :key_secret, null: false
      t.text :webhook_secret

      t.timestamps
    end

    add_index :event_payment_gateways, [:event_id, :provider], unique: true
  end
end
