class RemoveImagePathFromVendorProfiles < ActiveRecord::Migration[8.0]
  def change
    remove_column :vendor_profiles, :image_path, :string
  end
end
