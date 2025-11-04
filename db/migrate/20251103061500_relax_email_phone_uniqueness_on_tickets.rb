class RelaxEmailPhoneUniquenessOnTickets < ActiveRecord::Migration[8.0]
  def change
    # Remove unique constraints that conflict with business rule (same phone/email allowed if names differ)
    remove_index :tickets, name: "idx_tickets_event_email_norm_unique"
    remove_index :tickets, name: "idx_tickets_event_phone_norm_unique"

    # Re-add as non-unique indexes for performant lookups
    add_index :tickets, [:event_id, :attendee_email_norm], where: "attendee_email_norm IS NOT NULL", name: "idx_tickets_event_email_norm"
    add_index :tickets, [:event_id, :attendee_phone_norm], where: "attendee_phone_norm IS NOT NULL", name: "idx_tickets_event_phone_norm"
  end
end
