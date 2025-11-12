class ChangeVendorProfilesToGroupBased < ActiveRecord::Migration[7.1]
  def up
    # Delete all existing vendor_profiles (no production data)
    execute "DELETE FROM vendor_profiles"

    # Remove foreign key and index on event_id
    remove_foreign_key :vendor_profiles, :events if foreign_key_exists?(:vendor_profiles, :events)
    remove_index :vendor_profiles, :event_id if index_exists?(:vendor_profiles, :event_id)
    remove_index :vendor_profiles, [:event_id, :vendor_id] if index_exists?(:vendor_profiles, [:event_id, :vendor_id])

    # Remove event_id column
    remove_column :vendor_profiles, :event_id, :bigint

    # Add group_id column
    add_column :vendor_profiles, :group_id, :bigint, null: false
    add_foreign_key :vendor_profiles, :groups

    # Add indexes
    add_index :vendor_profiles, :group_id
    add_index :vendor_profiles, [:group_id, :vendor_id], unique: true
  end

  def down
    # Remove foreign key and index on group_id
    remove_foreign_key :vendor_profiles, :groups if foreign_key_exists?(:vendor_profiles, :groups)
    remove_index :vendor_profiles, :group_id if index_exists?(:vendor_profiles, :group_id)
    remove_index :vendor_profiles, [:group_id, :vendor_id] if index_exists?(:vendor_profiles, [:group_id, :vendor_id])

    # Remove group_id column
    remove_column :vendor_profiles, :group_id, :bigint

    # Add event_id column back
    add_column :vendor_profiles, :event_id, :bigint, null: false
    add_foreign_key :vendor_profiles, :events

    # Add indexes back
    add_index :vendor_profiles, :event_id
    add_index :vendor_profiles, [:event_id, :vendor_id], unique: true
  end
end
