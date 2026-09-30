# frozen_string_literal: true

# A checked-in attendee who has not answered the feedback form yet.
class FeedbackNonResponderSerializer
  def self.serialize(ticket, last_emailed_at: nil)
    {
      public_id: ticket.public_id,
      attendee_name: ticket.attendee_name,
      attendee_email: ticket.attendee_email,
      ticket_type_name: ticket.ticket_type&.name,
      checked_in_at: ticket.check_in_at,
      last_emailed_at:
    }
  end
end
