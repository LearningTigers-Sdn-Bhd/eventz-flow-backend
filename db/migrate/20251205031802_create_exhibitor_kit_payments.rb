class CreateExhibitorKitPayments < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_kit_payments do |t|
      t.references :exhibitor_kit, null: false, foreign_key: true
      t.references :payee, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 10, scale: 2, default: 0.0
      t.integer :status, default: 0
      t.string :payment_source
      t.string :payment_proof_url
      t.string :external_ref
      t.text :note
      t.datetime :paid_at

      t.timestamps
    end
  end
end
