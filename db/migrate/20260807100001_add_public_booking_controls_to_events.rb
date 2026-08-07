class AddPublicBookingControlsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :business_matching_public_booking_enabled, :boolean, default: true, null: false
    add_column :events, :business_matching_public_booking_cutoff_date, :date
  end
end
