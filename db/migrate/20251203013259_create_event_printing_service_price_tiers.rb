class CreateEventPrintingServicePriceTiers < ActiveRecord::Migration[8.0]
  def change
    create_table :event_printing_service_price_tiers do |t|
      t.references :event_printing_service, null: false, foreign_key: true
      t.decimal :price, precision: 8, scale: 2
      t.datetime :start_date
      t.datetime :end_date
      t.string :label

      t.timestamps
    end
  end
end
