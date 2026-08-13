class AddBookerProfileFieldsToBusinessMatchingBookings < ActiveRecord::Migration[8.0]
  def change
    add_column :business_matching_bookings, :booker_description, :text
    add_column :business_matching_bookings, :booker_sourcing_intent, :text
    add_column :business_matching_bookings, :booker_capabilities, :text
  end
end
