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
      matching_delivery = create(:email_delivery, related: event_ticket, event_id: event.id)
      create(:email_delivery, related: other_ticket, event_id: other_event.id)

      get '/v1/email_deliveries', params: { event_id: event.id }, headers: headers

      expect(response).to have_http_status(:ok)
      ids = JSON.parse(response.body)['data'].map { |row| row['id'] }
      expect(ids).to contain_exactly(matching_delivery.id)
    end
  end

  describe 'GET /v1/email_deliveries with search' do
    it 'matches recipient, subject or mailer across all rows' do
      by_recipient = create(:email_delivery, recipient: 'zed@example.com', subject: 'Hello')
      by_subject = create(:email_delivery, recipient: 'a@example.com', subject: 'Your zed pass')
      create(:email_delivery, recipient: 'other@example.com', subject: 'Unrelated')

      get '/v1/email_deliveries', params: { search: 'zed' }, headers: headers

      ids = JSON.parse(response.body)['data'].map { |row| row['id'] }
      expect(ids).to contain_exactly(by_recipient.id, by_subject.id)
    end

    it 'filters by status and paginates server-side' do
      create_list(:email_delivery, 3, :failed)
      create(:email_delivery, :delivered)

      get '/v1/email_deliveries', params: { status: 'failed', per_page: 2, page: 2 }, headers: headers

      body = JSON.parse(response.body)
      expect(body['data'].size).to eq(1)
      expect(body['pagination']).to include('total_count' => 3, 'total_pages' => 2, 'current_page' => 2)
    end
  end

  describe 'GET /v1/email_deliveries/summary' do
    it 'returns row counts per status for org owners' do
      create_list(:email_delivery, 2, :failed)
      create(:email_delivery, :delivered)

      get '/v1/email_deliveries/summary', headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to include('failed' => 2, 'delivered' => 1)
    end

    it 'rejects organizers' do
      get '/v1/email_deliveries/summary', headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'email log retention settings' do
    it 'returns the settings with a preview of rows to purge' do
      create(:email_delivery, :delivered, created_at: 800.days.ago)
      create(:email_delivery, :delivered, created_at: 400.days.ago)
      create(:email_delivery, :delivered, created_at: 1.day.ago)

      get '/v1/email_deliveries/settings', headers: headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']).to include(
        'retention_days' => 730, 'protected_retention_days' => 1825, 'purge_enabled' => false, 'rows_to_purge' => 1
      )
    end

    it 'previews a change without saving it' do
      create(:email_delivery, :delivered, created_at: 800.days.ago)
      create(:email_delivery, :delivered, created_at: 400.days.ago)

      get '/v1/email_deliveries/settings', params: { retention_days: 365, protected_retention_days: 730 }, headers: headers

      expect(JSON.parse(response.body)['data']).to include('retention_days' => 365, 'rows_to_purge' => 2)
      expect(EmailLogSetting.current.retention_days).to eq(730)
    end

    it 'rejects an invalid preview' do
      get '/v1/email_deliveries/settings', params: { retention_days: 10 }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'lets org owners update the windows' do
      patch '/v1/email_deliveries/settings',
            params: { retention_days: 180, protected_retention_days: 365, purge_enabled: true }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(EmailLogSetting.current).to have_attributes(
        retention_days: 180, protected_retention_days: 365, purge_enabled: true
      )
    end

    it 'rejects invalid windows' do
      patch '/v1/email_deliveries/settings',
            params: { retention_days: 10, protected_retention_days: 365 }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(EmailLogSetting.current.retention_days).to eq(730)
    end

    it 'rejects organizers' do
      patch '/v1/email_deliveries/settings',
            params: { retention_days: 180, protected_retention_days: 365 }, headers: auth_headers(organizer)

      expect(response).to have_http_status(:forbidden)
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
