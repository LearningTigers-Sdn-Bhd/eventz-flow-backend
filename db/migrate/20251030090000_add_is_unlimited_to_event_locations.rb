class AddIsUnlimitedToEventLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :event_locations, :is_unlimited, :boolean, default: false, null: false
  end
end
