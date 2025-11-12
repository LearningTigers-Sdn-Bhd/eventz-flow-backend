class CreateVendorProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :vendor_profiles do |t|
      t.references :event, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: { to_table: :users }
      t.string :redirect_url
      t.string :image_path
      t.string :vendor_name, null: false, default: 'Vendor Name'
      t.text :vendor_description

      t.timestamps
    end

    # Unique index to ensure one profile per event-vendor combination
    add_index :vendor_profiles, [:event_id, :vendor_id], unique: true
  end
end
