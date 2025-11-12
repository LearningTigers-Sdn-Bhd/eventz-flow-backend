class CreateEventVendorTables < ActiveRecord::Migration[8.0]
  def change
    # Create exhibitor_owners table
    create_table :exhibitor_owners do |t|
      t.string :name, null: false
      t.text :description
      t.string :contact_email
      t.string :contact_phone

      t.timestamps
    end

    add_index :exhibitor_owners, :name

    # Create vendor_profiles table (group-based from start)
    create_table :vendor_profiles do |t|
      t.references :group, null: false, foreign_key: true, index: false
      t.references :vendor, null: false, foreign_key: { to_table: :users }, index: false
      t.references :manager, null: true, foreign_key: { to_table: :users }, index: false
      t.string :image_path
      t.string :vendor_name, null: false, default: 'Vendor Name'
      t.text :vendor_description

      t.timestamps
    end

    add_index :vendor_profiles, :group_id
    add_index :vendor_profiles, [:group_id, :vendor_id], unique: true

    # Create event_vendors table (with type and exhibitor_owner_id from start)
    create_table :event_vendors do |t|
      t.references :event, null: false, foreign_key: true, index: false
      t.references :vendor, null: false, foreign_key: { to_table: :users }, index: false
      t.string :redirect_url, null: false
      t.string :poster_url
      t.string :type, null: false
      t.references :exhibitor_owner, null: true, foreign_key: { to_table: :exhibitor_owners }, index: false

      t.timestamps
    end

    add_index :event_vendors, :type
    add_index :event_vendors, :vendor_id
    add_index :event_vendors, :exhibitor_owner_id
    add_index :event_vendors, [:event_id, :vendor_id], unique: true, name: "index_event_vendors_on_event_and_vendor"
  end
end
