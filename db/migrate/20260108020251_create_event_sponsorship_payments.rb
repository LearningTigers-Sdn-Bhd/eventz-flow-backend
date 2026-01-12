class CreateEventSponsorshipPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :event_sponsorship_payments do |t|
      t.references :event_sponsorship, null: false, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2
      t.string :currency, default: "MYR"
      t.datetime :received_at
      t.integer :method
      t.string :reference_no
      t.text :notes
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :event_sponsorship_payments, :deleted_at
  end
end