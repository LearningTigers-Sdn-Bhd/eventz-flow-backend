class AddPublicIdToVisitorsAndRemoveVendorId < ActiveRecord::Migration[8.0]
  def change
    # Remove vendor_id foreign key and column
    remove_foreign_key :visitors, :users, column: :vendor_id
    remove_column :visitors, :vendor_id, :bigint

    # Remove composite index on event_id and vendor_id
    remove_index :visitors, [:event_id, :vendor_id] if index_exists?(:visitors, [:event_id, :vendor_id])

    # Add public_id column (UUID)
    add_column :visitors, :public_id, :uuid, default: 'gen_random_uuid()', null: false

    # Add unique index on public_id for fast lookups
    add_index :visitors, :public_id, unique: true
  end
end
