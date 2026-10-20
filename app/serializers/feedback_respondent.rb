# frozen_string_literal: true

# Who answered: a ticket holder, or an exhibitor company. Both come back in the
# attendee_* shape the organizer screens already render; exhibitors read as
# "Exhibitor" in the type column, with their booth numbers alongside.
class FeedbackRespondent
  def self.for(response)
    if response.exhibitor
      company = ExhibitorCertificate.new(response.exhibitor)
      {
        public_id: nil,
        attendee_name: company.company_name,
        attendee_email: company.email,
        ticket_type_name: 'Exhibitor',
        booth_numbers: company.booth_numbers
      }
    elsif (ticket = response.ticket)
      {
        public_id: ticket.public_id,
        attendee_name: ticket.attendee_name,
        attendee_email: ticket.attendee_email,
        ticket_type_name: ticket.ticket_type&.name
      }
    end
  end
end
