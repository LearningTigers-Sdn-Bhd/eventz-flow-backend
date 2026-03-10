class AddRotationToEventSeatSections < ActiveRecord::Migration[8.0]
  def change
    add_column :event_seat_sections, :rotation, :float, default: 0.0, null: false
  end
end
