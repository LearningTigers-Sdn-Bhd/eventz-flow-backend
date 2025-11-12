class CreateVisitorTables < ActiveRecord::Migration[8.0]
  def change
    # Create visitors table (with public_id from start, no vendor_id)
    create_table :visitors do |t|
      t.references :event, null: false, foreign_key: true, index: false
      t.uuid :public_id, default: 'gen_random_uuid()', null: false
      t.string :full_name
      t.string :gender
      t.integer :age
      t.string :phone
      t.string :email

      t.timestamps
    end

    add_index :visitors, :public_id, unique: true
    add_index :visitors, :event_id

    # Create visitor_vendor_stamps table (not user_engage_vendors)
    create_table :visitor_vendor_stamps do |t|
      t.references :visitor, null: false, foreign_key: true, index: false
      t.references :event_vendor, null: false, foreign_key: true, index: false

      t.timestamps
    end

    add_index :visitor_vendor_stamps, [:visitor_id, :event_vendor_id], unique: true, name: 'index_visitor_vendor_stamps_on_visitor_and_event_vendor'
    add_index :visitor_vendor_stamps, :visitor_id
    add_index :visitor_vendor_stamps, :event_vendor_id
  end
end
