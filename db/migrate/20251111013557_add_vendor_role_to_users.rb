class AddVendorRoleToUsers < ActiveRecord::Migration[8.0]
  def change
    # Note: The role enum is stored as integer in the database
    # Adding vendor: 3 to the enum in the User model is sufficient
    # No database migration needed as the column already supports integer values
  end
end
