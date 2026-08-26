require 'rails_helper'

RSpec.describe 'V1::TicketApplications', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:event) { create(:event) }
  let(:registration_form) { create(:registration_form, event: event) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:ticket) { create(:ticket, :pending_payment, event: event, ticket_type: ticket_type, attendee_email: 'delegate@example.com') }
  let!(:application) { create(:ticket_application, ticket: ticket, registration_form: registration_form) }
  let(:headers) { auth_headers(organizer) }

  before do
    create(:event_assignment, event: event, user: organizer, role: :event_admin)
    create(:registration_form_rsvp_setting, registration_form: registration_form, enabled: true, rsvp_required: true)
  end

  describe 'PATCH /v1/events/:event_id/tickets/:ticket_id/application/approve' do
    it 'approves application and sends RSVP state' do
      patch "/v1/events/#{event.id}/tickets/#{ticket.public_id}/application/approve", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['ticket_application']['review_status']).to eq('approved')
      expect(json['ticket_application']['rsvp_status']).to eq('sent')
      expect(ticket.reload.status).to eq('pending_payment')
    end
  end

  describe 'PATCH /v1/events/:event_id/tickets/:ticket_id/application/reject' do
    it 'rejects application and cancels ticket' do
      patch "/v1/events/#{event.id}/tickets/#{ticket.public_id}/application/reject",
            headers: headers,
            params: { reason: 'Limited seats' },
            as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['ticket_application']['review_status']).to eq('rejected')
      expect(ticket.reload.status).to eq('canceled')
    end
  end

  describe 'PATCH /v1/events/:event_id/tickets/:ticket_id/application/revert' do
    it 'reverts an approved, manually-paid application back to pending' do
      application.update!(review_status: :approved)
      ticket.update!(status: :purchased, payment_status: :paid)
      create(:ticket_payment, ticket: ticket, status: 'paid', gateway: nil)

      patch "/v1/events/#{event.id}/tickets/#{ticket.public_id}/application/revert", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['ticket_application']['review_status']).to eq('pending_review')
      expect(ticket.reload.status).to eq('pending_payment')
      expect(ticket.payment_status).to eq('pending')
    end

    it 'returns unprocessable when ticket was paid via gateway and not confirmed' do
      application.update!(review_status: :approved)
      ticket.update!(status: :purchased, payment_status: :paid)
      create(:ticket_payment, ticket: ticket, status: 'paid', gateway: 'razorpay')

      patch "/v1/events/#{event.id}/tickets/#{ticket.public_id}/application/revert", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(application.reload.review_status).to eq('approved')
    end
  end

  describe 'POST /v1/events/:event_id/tickets/:ticket_id/application/resend_rsvp' do
    it 'resends RSVP for approved application' do
      application.update!(review_status: :approved, rsvp_status: :sent)

      post "/v1/events/#{event.id}/tickets/#{ticket.public_id}/application/resend_rsvp", headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['ticket_application']['rsvp_status']).to eq('sent')
    end
  end
end
