class AddBusinessMatchingAutoApproveBookingsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :business_matching_auto_approve_bookings, :boolean, null: false, default: false
  end
end
