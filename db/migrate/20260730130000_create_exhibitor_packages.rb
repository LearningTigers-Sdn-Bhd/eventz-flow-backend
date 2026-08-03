class CreateExhibitorPackages < ActiveRecord::Migration[8.0]
  def change
    create_table :exhibitor_packages do |t|
      t.references :event, null: false, foreign_key: true
      t.references :exhibitor_booth_price, null: false, foreign_key: true
      t.string :name, null: false
      t.text :inclusions
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :quota

      t.timestamps
    end

    add_index :exhibitor_packages, %i[event_id name], unique: true,
      name: 'index_exhibitor_packages_on_event_id_and_name'
  end
end
