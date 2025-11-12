class UpdateVendorProfiles < ActiveRecord::Migration[8.0]
  def change
    remove_column :vendor_profiles, :redirect_url, :string
    add_reference :vendor_profiles, :manager, foreign_key: { to_table: :users }, null: true
  end
end
