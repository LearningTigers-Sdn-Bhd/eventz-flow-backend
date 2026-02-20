class UpdateSeatTicketingFields < ActiveRecord::Migration[8.0]
  def change
    rename_column :event_seat_venues, :row, :total_row
    rename_column :event_seat_venues, :column, :total_column

    rename_column :event_seat_sections, :prize, :price
    rename_column :event_seat_sections, :seat_row, :start_row
    rename_column :event_seat_sections, :seat_column, :start_column
    add_column :event_seat_sections, :seat_row, :integer, default: 1
    add_column :event_seat_sections, :seat_column, :integer, default: 1
  end
end
