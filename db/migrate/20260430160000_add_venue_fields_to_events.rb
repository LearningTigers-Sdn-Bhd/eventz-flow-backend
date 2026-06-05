class AddVenueFieldsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :venue_name, :string
    add_column :events, :venue_address, :string
  end
end
