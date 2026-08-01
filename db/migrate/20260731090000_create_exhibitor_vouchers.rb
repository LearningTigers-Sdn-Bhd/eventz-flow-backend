class CreateExhibitorVouchers < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_vouchers do |t|
      t.references :event, null: false, foreign_key: true
      t.references :exhibitor_booth_price, foreign_key: true
      t.references :exhibitor_package, foreign_key: true
      t.string :code, null: false
      t.integer :discount_type, null: false
      t.decimal :discount_value, precision: 10, scale: 2, null: false
      t.integer :status, null: false, default: 0
      t.bigint :redeemed_by_exhibitor_kit_id
      t.datetime :redeemed_at

      t.timestamps
    end

    add_index :exhibitor_vouchers, :code, unique: true
    add_index :exhibitor_vouchers, :redeemed_by_exhibitor_kit_id
    add_foreign_key :exhibitor_vouchers, :exhibitor_kits,
      column: :redeemed_by_exhibitor_kit_id, on_delete: :nullify
  end
end
