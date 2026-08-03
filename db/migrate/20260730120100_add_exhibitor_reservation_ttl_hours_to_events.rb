class AddExhibitorReservationTtlHoursToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :exhibitor_reservation_ttl_hours, :integer
  end
end
