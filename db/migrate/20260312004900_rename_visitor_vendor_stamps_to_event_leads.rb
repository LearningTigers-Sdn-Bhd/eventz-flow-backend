class RenameVisitorVendorStampsToEventLeads < ActiveRecord::Migration[8.0]
  def up
    # 1. Rename the table
    rename_table :visitor_vendor_stamps, :event_leads

    # 2. Add polymorphic columns
    add_column :event_leads, :leadable_type, :string
    add_column :event_leads, :leadable_id, :bigint

    # 3. Migrate existing data: all current records are Visitors
    execute <<-SQL
      UPDATE event_leads
      SET leadable_type = 'Visitor', leadable_id = visitor_id
    SQL

    # 3b. Remove orphaned records where visitor_id was NULL (leadable_id would be NULL)
    execute <<-SQL
      DELETE FROM event_leads WHERE leadable_id IS NULL
    SQL

    # 4. Add NOT NULL constraints after data migration
    change_column_null :event_leads, :leadable_type, false
    change_column_null :event_leads, :leadable_id, false

    # 5. Add notes and scanned_by
    add_column :event_leads, :notes, :text
    add_column :event_leads, :scanned_by_id, :bigint

    # 6. Remove old indexes that reference visitor_id
    remove_index :event_leads, :visitor_id, if_exists: true
    remove_index :event_leads, [:visitor_id, :event_vendor_id], if_exists: true

    # 7. Remove old foreign key and column
    remove_foreign_key :event_leads, :visitors
    remove_column :event_leads, :visitor_id

    # 8. Ensure old event_vendor index name is updated when needed
    if index_name_exists?(:event_leads, 'index_visitor_vendor_stamps_on_event_vendor_id') &&
       !index_name_exists?(:event_leads, 'index_event_leads_on_event_vendor_id')
      rename_index :event_leads,
             'index_visitor_vendor_stamps_on_event_vendor_id',
             'index_event_leads_on_event_vendor_id'
    end

    # 9. Add new indexes
    add_index :event_leads, [:leadable_type, :leadable_id],
              name: 'index_event_leads_on_leadable'
    add_index :event_leads, [:leadable_type, :leadable_id, :event_vendor_id],
              unique: true,
              name: 'index_event_leads_on_leadable_and_event_vendor'

    # 10. Add foreign keys
    add_foreign_key :event_leads, :users, column: :scanned_by_id, on_delete: :nullify
  end

  def down
    # Remove new foreign key
    remove_foreign_key :event_leads, column: :scanned_by_id

    # Remove new indexes
    remove_index :event_leads, name: 'index_event_leads_on_leadable_and_event_vendor', if_exists: true
    remove_index :event_leads, name: 'index_event_leads_on_leadable', if_exists: true

    # Re-add visitor_id column
    add_column :event_leads, :visitor_id, :bigint

    # Migrate data back (only Visitor type)
    execute <<-SQL
      UPDATE event_leads
      SET visitor_id = leadable_id
      WHERE leadable_type = 'Visitor'
    SQL

    # Remove polymorphic columns, notes, and scanned_by
    remove_column :event_leads, :scanned_by_id
    remove_column :event_leads, :notes
    remove_column :event_leads, :leadable_id
    remove_column :event_leads, :leadable_type

    # Re-add old indexes
    add_index :event_leads, :visitor_id, name: 'index_visitor_vendor_stamps_on_visitor_id'
    add_index :event_leads, [:visitor_id, :event_vendor_id],
              unique: true,
              name: 'index_visitor_vendor_stamps_on_visitor_and_event_vendor'

    # Re-add foreign key
    add_foreign_key :event_leads, :visitors

    # Rename index back when needed
    if index_name_exists?(:event_leads, 'index_event_leads_on_event_vendor_id') &&
       !index_name_exists?(:event_leads, 'index_visitor_vendor_stamps_on_event_vendor_id')
      rename_index :event_leads,
             'index_event_leads_on_event_vendor_id',
             'index_visitor_vendor_stamps_on_event_vendor_id'
    end

    # Rename table back
    rename_table :event_leads, :visitor_vendor_stamps
  end
end
