class CreateExhibitorKitPrintings < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_kit_printings do |t|
      t.references :exhibitor_kit, null: false, foreign_key: true
      t.references :printing_service, null: false, foreign_key: true
      t.integer :quantity
      t.decimal :agreed_price, precision: 8, scale: 2
      t.string :file_reference
      t.text :notes

      t.timestamps
    end
  end
end
