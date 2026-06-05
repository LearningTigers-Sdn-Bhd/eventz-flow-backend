require 'rails_helper'

RSpec.describe 'V1::Tickets resend confirmation email', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:event) { create(:event, payment_status: :paid) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:ticket) do
    create(
      :ticket,
      event: event,
      ticket_type: ticket_type,
      attendee_email: 'attendee@example.com'
    )
  end

  before do
    EventAssignment.find_or_create_by!(event: event, user: organizer, role: :event_admin)
  end

  describe 'POST /v1/events/:event_id/tickets/:id/resend_confirmation_email' do
    it 'allows org owner and queues confirmation email resend' do
      headers = auth_headers(org_owner)
      delivery = create(:email_delivery, status: 'queued')
      allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later).and_return(delivery)

      post "/v1/events/#{event.id}/tickets/#{ticket.public_id}/resend_confirmation_email", headers: headers

      expect(response).to have_http_status(:accepted)
      expect(EmailDelivery::AuditedDelivery).to have_received(:deliver_later).with(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket,
        metadata: hash_including(source: 'ticket_actions_menu_manual_resend', event_id: event.id)
      )
    end

    it 'allows organizer and queues confirmation email resend' do
      headers = auth_headers(organizer)
      delivery = create(:email_delivery, status: 'queued')
      allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later).and_return(delivery)

      post "/v1/events/#{event.id}/tickets/#{ticket.public_id}/resend_confirmation_email", headers: headers

      expect(response).to have_http_status(:accepted)
      expect(EmailDelivery::AuditedDelivery).to have_received(:deliver_later).with(
        mailer_name: 'TicketMailer',
        mailer_action: 'confirmation_email',
        args: [ticket],
        related: ticket,
        metadata: hash_including(source: 'ticket_actions_menu_manual_resend', event_id: event.id)
      )
    end
  end
end
