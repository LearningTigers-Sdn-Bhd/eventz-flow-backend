class AddBoothQuantityToExhibitorKits < ActiveRecord::Migration[8.0]
  def change
    add_column :exhibitor_kits, :booth_quantity, :integer, default: 1, null: false
  end
end
