class CreateItemCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :item_categories do |t|
      t.string :name
      t.boolean :active

      t.timestamps
    end
  end
end
