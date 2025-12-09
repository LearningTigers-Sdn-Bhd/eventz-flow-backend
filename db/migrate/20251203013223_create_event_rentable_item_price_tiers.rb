class CreateEventRentableItemPriceTiers < ActiveRecord::Migration[8.0]
  def change
    create_table :event_rentable_item_price_tiers do |t|
      t.references :event_rentable_item, null: false, foreign_key: true
      t.decimal :price, precision: 8, scale: 2
      t.datetime :start_date
      t.datetime :end_date
      t.string :label

      t.timestamps
    end
  end
end
