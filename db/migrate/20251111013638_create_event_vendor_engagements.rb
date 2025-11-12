class CreateEventVendorEngagements < ActiveRecord::Migration[8.0]
  def change
    create_table :event_vendor_engagements do |t|
      t.references :event, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: { to_table: :users }
      t.string :redirect_url, null: false
      t.string :poster_url

      t.timestamps
    end

    add_index :event_vendor_engagements, [:event_id, :vendor_id, :redirect_url], unique: true, name: 'index_event_vendor_engagements_unique'
  end
end
