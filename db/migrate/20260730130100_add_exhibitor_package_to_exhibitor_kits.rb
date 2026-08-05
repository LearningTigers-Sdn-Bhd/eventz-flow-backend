class AddExhibitorPackageToExhibitorKits < ActiveRecord::Migration[8.0]
  def change
    add_reference :exhibitor_kits, :exhibitor_package, foreign_key: true
  end
end
