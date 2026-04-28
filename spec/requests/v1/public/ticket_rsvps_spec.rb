require 'rails_helper'

RSpec.describe 'V1::Public::TicketRsvps', type: :request do
  let(:event) { create(:event, title: 'Sabah Impact Summit', status: :published) }
  let(:registration_form) { create(:registration_form, event: event, name: 'Interested Delegate', slug: 'interested-delegate') }
  let(:ticket_type) { create(:ticket_type, event: event, status: :published) }
  let(:ticket) { create(:ticket, :pending_payment, event: event, ticket_type: ticket_type, attendee_email: 'delegate@example.com') }
  let(:application) { create(:ticket_application, ticket: ticket, registration_form: registration_form, review_status: :approved, rsvp_status: :sent) }
  let(:raw_token) { application.assign_rsvp_token! }

  describe 'GET /v1/public/events/:event_slug/ticket_rsvp/:token' do
    it 'returns RSVP context' do
      get "/v1/public/events/#{event.slug}/ticket_rsvp/#{raw_token}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['attendee_name']).to eq(ticket.attendee_name)
      expect(json['data']['review_status']).to eq('approved')
      expect(json['data']['rsvp_status']).to eq('sent')
    end
  end

  describe 'POST /v1/public/events/:event_slug/ticket_rsvp/:token/confirm' do
    it 'confirms RSVP and purchases ticket' do
      post "/v1/public/events/#{event.slug}/ticket_rsvp/#{raw_token}/confirm"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['rsvp_status']).to eq('confirmed')
      expect(ticket.reload.status).to eq('purchased')
      expect(ticket.payment_status).to eq('paid')
    end
  end

  describe 'POST /v1/public/events/:event_slug/ticket_rsvp/:token/decline' do
    it 'declines RSVP without purchasing ticket' do
      post "/v1/public/events/#{event.slug}/ticket_rsvp/#{raw_token}/decline"

      expect(response).to have_http_status(:ok)
      expect(application.reload.rsvp_status).to eq('declined')
      expect(ticket.reload.status).to eq('pending_payment')
    end
  end
end
