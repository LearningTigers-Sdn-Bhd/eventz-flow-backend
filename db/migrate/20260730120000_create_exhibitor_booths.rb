class CreateExhibitorBooths < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_booths do |t|
      t.references :event, null: false, foreign_key: true
      t.references :exhibitor_booth_price, null: false, foreign_key: true
      t.references :exhibitor_kit, foreign_key: true
      t.string :number, null: false
      t.integer :status, null: false, default: 0
      t.timestamps
    end

    add_index :exhibitor_booths, %i[event_id number], unique: true
    add_index :exhibitor_booths, %i[exhibitor_booth_price_id status]
  end
end
