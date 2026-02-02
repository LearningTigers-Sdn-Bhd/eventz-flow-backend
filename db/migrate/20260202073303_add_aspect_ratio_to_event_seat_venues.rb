class AddAspectRatioToEventSeatVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :event_seat_venues, :aspect_ratio, :string
  end
end
