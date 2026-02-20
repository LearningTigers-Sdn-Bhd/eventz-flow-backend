class AddLockedAtToEventTicketSeats < ActiveRecord::Migration[8.0]
  def change
    create_table :event_seat_checkout_sessions, id: :uuid do |t|
      t.references :event_seat_session, null: false, foreign_key: true
      t.timestamps
    end
    add_column :event_ticket_seats, :locked_by_session_id, :uuid
    add_foreign_key :event_ticket_seats, :event_seat_checkout_sessions, column: :locked_by_session_id
    add_index :event_ticket_seats, :locked_by_session_id
  end
end
