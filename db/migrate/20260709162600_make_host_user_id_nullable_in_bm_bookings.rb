class MakeHostUserIdNullableInBmBookings < ActiveRecord::Migration[7.1]
  def change
    change_column_null :business_matching_bookings, :host_user_id, true
  end
end
