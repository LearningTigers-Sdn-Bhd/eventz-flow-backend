class CreateEventLocationMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :event_location_members do |t|
      t.references :event_location, null: false, foreign_key: true
      t.references :member, foreign_key: { to_table: :users }, null: true
      t.timestamps
    end

    add_index :event_location_members, [:event_location_id, :member_id], unique: true
  end
end
