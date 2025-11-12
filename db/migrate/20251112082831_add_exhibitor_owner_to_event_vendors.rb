class AddExhibitorOwnerToEventVendors < ActiveRecord::Migration[8.0]
  def up
    unless column_exists?(:event_vendors, :exhibitor_owner_id)
      add_reference :event_vendors, :exhibitor_owner, null: true, foreign_key: { to_table: :exhibitor_owners }
    end

    unless index_exists?(:event_vendors, :exhibitor_owner_id)
      add_index :event_vendors, :exhibitor_owner_id
    end
  end

  def down
    if column_exists?(:event_vendors, :exhibitor_owner_id)
      remove_reference :event_vendors, :exhibitor_owner, foreign_key: { to_table: :exhibitor_owners }
    end
  end
end
