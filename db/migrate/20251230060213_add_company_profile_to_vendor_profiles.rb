class AddCompanyProfileToVendorProfiles < ActiveRecord::Migration[8.0]
  def change
    add_column :vendor_profiles, :company_profile, :text
  end
end
