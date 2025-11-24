class AddLocationDetailsToEventLocations < ActiveRecord::Migration[8.0]
  def change
    add_column :event_locations, :floor, :string
    # Composite index for efficient queries by event and floor
    add_index :event_locations, [:event_id, :floor]
    
    # Add JSONB column to store detailed location information (wing, booth, zone, notes)
    add_column :event_locations, :location_details, :jsonb, default: {}
    
    # Add GIN index for efficient JSONB queries
    add_index :event_locations, :location_details, using: :gin
  end
end
