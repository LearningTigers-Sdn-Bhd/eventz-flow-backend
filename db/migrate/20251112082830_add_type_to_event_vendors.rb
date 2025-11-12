class AddTypeToEventVendors < ActiveRecord::Migration[8.0]
  def change
    add_column :event_vendors, :type, :string
    add_index :event_vendors, :type
  end
end

