class RefactorVendorProfilesToBeVendorCentric < ActiveRecord::Migration[8.0]
  def up
    # Remove group_id - vendor profiles are no longer group-specific
    remove_index :vendor_profiles, name: "index_vendor_profiles_on_group_id_and_vendor_id"
    remove_index :vendor_profiles, name: "index_vendor_profiles_on_group_id"
    remove_foreign_key :vendor_profiles, :groups
    remove_column :vendor_profiles, :group_id, :bigint
    
    # Remove manager_id - use users.created_by_id instead
    remove_foreign_key :vendor_profiles, column: :manager_id
    remove_column :vendor_profiles, :manager_id, :bigint
    
    # Remove vendor_name - use users.full_name instead
    remove_column :vendor_profiles, :vendor_name, :string
    
    # Rename vendor_description to description for clarity
    rename_column :vendor_profiles, :vendor_description, :description
    
    # Add new vendor business information fields
    add_column :vendor_profiles, :category, :string
    add_column :vendor_profiles, :person_in_charge, :string
    add_column :vendor_profiles, :address, :text
    add_column :vendor_profiles, :notes, :text
    
    # Clean up duplicate vendor profiles before adding unique constraint
    # Keep the most recently updated profile for each vendor
    execute <<-SQL
      DELETE FROM vendor_profiles
      WHERE id NOT IN (
        SELECT DISTINCT ON (vendor_id) id
        FROM vendor_profiles
        ORDER BY vendor_id, updated_at DESC
      );
    SQL
    
    # Add unique index on vendor_id - one profile per vendor
    add_index :vendor_profiles, :vendor_id, unique: true
  end
  
  def down
    # Remove unique index
    remove_index :vendor_profiles, :vendor_id
    
    # Remove new columns
    remove_column :vendor_profiles, :notes, :text
    remove_column :vendor_profiles, :address, :text
    remove_column :vendor_profiles, :person_in_charge, :string
    remove_column :vendor_profiles, :category, :string
    
    # Rename description back to vendor_description
    rename_column :vendor_profiles, :description, :vendor_description
    
    # Add back vendor_name
    add_column :vendor_profiles, :vendor_name, :string, default: 'Vendor Name', null: false
    
    # Add back manager_id
    add_column :vendor_profiles, :manager_id, :bigint
    add_foreign_key :vendor_profiles, :users, column: :manager_id
    
    # Add back group_id
    add_column :vendor_profiles, :group_id, :bigint, null: false
    add_foreign_key :vendor_profiles, :groups
    add_index :vendor_profiles, :group_id
    add_index :vendor_profiles, [:group_id, :vendor_id], unique: true
  end
end
