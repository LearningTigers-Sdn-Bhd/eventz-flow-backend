require 'rails_helper'

RSpec.describe 'V1::EmailDeliveries', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }
  let(:headers) { auth_headers(org_owner) }

  describe 'GET /v1/email_deliveries' do
    it 'lists email deliveries for org owners' do
      create(:email_delivery, :delivered, recipient: 'attendee@example.com')

      get '/v1/email_deliveries', headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data'].first['recipient']).to eq('attendee@example.com')
    end

    it 'rejects organizers' do
      get '/v1/email_deliveries', headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
    end

    it 'rejects members' do
      get '/v1/email_deliveries', headers: auth_headers(member)

      expect(response).to have_http_status(:forbidden)
    end

    it 'filters to stuck sent emails older than 24 hours' do
      older_sent = create(:email_delivery, :sent, sent_at: 25.hours.ago)
      create(:email_delivery, :sent, sent_at: 2.hours.ago)
      create(:email_delivery, :failed)

      get '/v1/email_deliveries', params: { stuck_sent: true }, headers: headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body)['data'].map { |row| row['id'] }
      expect(ids).to contain_exactly(older_sent.id)
    end

    it 'filters email deliveries by event id' do
      event = create(:event)
      other_event = create(:event)
      event_ticket = create(:ticket, event: event)
      other_ticket = create(:ticket, event: other_event)
      matching_delivery = create(:email_delivery, related: event_ticket)
      create(:email_delivery, related: other_ticket)

      get '/v1/email_deliveries', params: { event_id: event.id }, headers: headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body)['data'].map { |row| row['id'] }
      expect(ids).to contain_exactly(matching_delivery.id)
    end
  end

  describe 'POST /v1/email_deliveries/:id/resend' do
    it 'resends eligible failed emails' do
      delivery = create(:email_delivery, :failed)
      new_delivery = create(:email_delivery, status: 'queued')
      allow(EmailDelivery::Resender).to receive(:call).and_return(
        EmailDelivery::Resender::Result.new(success: true, delivery: new_delivery, errors: [])
      )

      post "/v1/email_deliveries/#{delivery.id}/resend", headers: headers

      expect(response).to have_http_status(:accepted)
      expect(EmailDelivery::Resender).to have_received(:call).with(delivery)
    end
  end
end
