class CreateExhibitorBoothPriceTiers < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_booth_price_tiers do |t|
      t.references :exhibitor_booth_price, null: false, foreign_key: true
      t.decimal :price, precision: 10, scale: 2, null: false
      t.datetime :start_date, null: false
      t.datetime :end_date
      t.string :label, null: false

      t.timestamps
    end

    add_index :exhibitor_booth_price_tiers, :start_date
    add_index :exhibitor_booth_price_tiers, [:exhibitor_booth_price_id, :start_date],
              name: 'idx_exhibitor_booth_price_tiers_on_booth_price_and_start'
  end
end
