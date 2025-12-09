class CreatePrintingServices < ActiveRecord::Migration[8.0]
  def change
    create_table :printing_services do |t|
      t.string :name
      t.text :description
      t.string :unit_of_measure
      t.decimal :default_price, precision: 8, scale: 2, default: 0
      t.integer :status
      t.references :item_category, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
