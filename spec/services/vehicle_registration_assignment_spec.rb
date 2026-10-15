require 'rails_helper'

RSpec.describe VehicleRegistrationAssignment do
  it 'does not retry a unique violation raised by the ticket record' do
    event = create(:event)
    form = create(:registration_form, event: event, slug: 'expedition-tags-on')
    ticket_type = create(
      :ticket_type,
      event: event,
      name: 'Expedition - Member',
      status: :published,
      hidden: false
    )
    create(:registration_form_ticket_type, registration_form: form, ticket_type: ticket_type)
    ticket = event.tickets.new(
      ticket_type: ticket_type,
      attendee_name: 'Ali',
      status: :pending_payment,
      payment_status: :pending
    )
    ticket_unique_error = ActiveRecord::RecordNotUnique.new(
      'duplicate key violates unique constraint "idx_tickets_unique_membership_no"'
    )
    attempts = 0
    allow(ticket).to receive(:save) do
      attempts += 1
      raise ticket_unique_error if attempts == 1

      raise 'ticket save was unexpectedly retried'
    end

    expect do
      described_class.new(
        event: event,
        form: form,
        ticket: ticket,
        plate: 'SAA 101'
      ).save
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
