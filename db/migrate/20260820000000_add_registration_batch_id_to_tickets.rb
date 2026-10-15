class AddRegistrationBatchIdToTickets < ActiveRecord::Migration[8.0]
  def change
    # Groups tickets created in one registration submission (primary +
    # group_attendees siblings). Nil for standalone tickets. Lets payment
    # confirmation scope to "tickets from this submission" instead of
    # "any pending ticket with this email" — the latter wrongly swept up
    # an unrelated later submission by the same email/ticket_type.
    add_column :tickets, :registration_batch_id, :uuid
    add_index :tickets, :registration_batch_id
  end
end
