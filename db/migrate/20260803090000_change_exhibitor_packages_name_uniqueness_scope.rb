class ChangeExhibitorPackagesNameUniquenessScope < ActiveRecord::Migration[8.0]
  def change
    remove_index :exhibitor_packages, name: 'index_exhibitor_packages_on_event_id_and_name'

    add_index :exhibitor_packages, %i[event_id exhibitor_booth_price_id name], unique: true,
      name: 'index_exhibitor_packages_on_event_booth_price_and_name'
  end
end
