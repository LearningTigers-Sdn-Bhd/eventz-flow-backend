class CreateExhibitorKitItems < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_kit_items do |t|
      t.references :exhibitor_kit, null: false, foreign_key: true
      t.references :rentable_item, null: false, foreign_key: true
      t.integer :quantity
      t.decimal :agreed_price, precision: 8, scale: 2
      t.text :notes

      t.timestamps
    end
  end
end
