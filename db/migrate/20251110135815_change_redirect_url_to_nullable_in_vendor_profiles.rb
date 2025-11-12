class ChangeRedirectUrlToNullableInVendorProfiles < ActiveRecord::Migration[8.0]
  def change
    change_column_null :vendor_profiles, :redirect_url, true
  end
end
