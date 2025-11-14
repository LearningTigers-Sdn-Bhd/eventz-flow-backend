class RemoveUniquenessFromGroupAffiliates < ActiveRecord::Migration[8.0]
  def change
    # Remove the unique index on group_id to allow multiple vendors per group
    remove_index :group_affiliates, :group_id
    
    # Add a regular index on group_id for query performance
    add_index :group_affiliates, :group_id
    
    # Add a composite unique index to prevent duplicate vendor assignments to the same group
    add_index :group_affiliates, [:group_id, :vendor_id], unique: true
  end
end
