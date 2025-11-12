class FixEventVendorsUniquenessConstraint < ActiveRecord::Migration[8.0]
  def change
    # Remove old unique index that includes redirect_url
    remove_index :event_vendors, name: "index_event_vendors_unique"

    # Add new unique index on just event_id and vendor_id (1 vendor per event)
    add_index :event_vendors, [:event_id, :vendor_id], unique: true, name: "index_event_vendors_on_event_and_vendor"
  end
end
