class ChangeAttendeeEmailNullableInTickets < ActiveRecord::Migration[8.0]
  def change
    change_column_null :tickets, :attendee_email, true
  end
end
