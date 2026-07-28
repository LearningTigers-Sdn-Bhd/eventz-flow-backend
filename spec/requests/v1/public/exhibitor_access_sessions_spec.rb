require 'rails_helper'

RSpec.describe 'Public exhibitor access', type: :request do
  let(:event) { create(:event, status: :published) }

  describe 'POST /exhibitor_email_status' do
    it 'returns existing without sending access for a global user or exposing account details' do
      create(:user, email: 'owner@example.com')

      expect {
        post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: ' OWNER@example.com ' }
      }.not_to change(PublicExhibitorAccessSession, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('success' => true, 'data' => { 'existing' => true, 'has_booking' => false })
      expect(response.body).not_to include('user_id', 'role', 'event_vendor', 'exhibitor')
    end

    it 'treats an event exhibitor as existing' do
      vendor = create(:user, :vendor, email: 'exhibitor@example.com')
      create(:exhibitor, event: event, vendor: vendor)

      post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: vendor.email }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'existing')).to be(true)
      expect(response.parsed_body.dig('data', 'has_booking')).to be(false)
    end

    it 'reports a booth booking only for an exhibitor kit in this event' do
      vendor = create(:user, :vendor, email: 'booked@example.com')
      exhibitor = create(:exhibitor, event: event, vendor: vendor)
      create(:exhibitor_kit, event_vendor: exhibitor)

      post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: vendor.email }

      expect(response.parsed_body.fetch('data')).to include('existing' => true, 'has_booking' => true)
    end

    it 'returns new without issuing access or creating an account' do
      expect {
        post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: 'new@example.com' }
      }.not_to change(PublicExhibitorAccessSession, :count)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig('data', 'existing')).to be(false)
      expect(response.parsed_body.dig('data', 'new_registration_token')).to be_present
      expect(User.find_by(email: 'new@example.com')).to be_nil
    end

    it 'does not issue a new-registration token for an existing account' do
      create(:user, email: 'owner@example.com')

      post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: 'owner@example.com' }

      expect(response.parsed_body.dig('data', 'new_registration_token')).to be_nil
    end

    it 'rejects invalid email without revealing status' do
      post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: 'not-an-email' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq('success' => false, 'message' => 'Enter a valid email address.')
    end
  end

  it 'returns identical accepted responses without issuing reusable access for brand-new emails' do
    vendor = create(:user, :vendor, email: 'known@example.com')
    create(:exhibitor, event: event, vendor: vendor)

    post "/v1/public/events/#{event.slug}/exhibitor_access_requests", params: { email: 'known@example.com' }
    known = [response.status, response.parsed_body]
    post "/v1/public/events/#{event.slug}/exhibitor_access_requests", params: { email: 'unknown@example.com' }

    expect([response.status, response.parsed_body]).to eq(known)
    expect(response).to have_http_status(:accepted)
    expect(PublicExhibitorAccessSession.where(event: event).pluck(:normalized_email))
      .to contain_exactly('known@example.com')
  end

  it 'exchanges one challenge and scopes session to its event' do
    access, challenge = PublicExhibitorAccessSession.issue_challenge!(event: event, email: 'known@example.com')

    post "/v1/public/events/#{event.slug}/exhibitor_access_sessions", params: { challenge: challenge }
    token = response.parsed_body.dig('data', 'session_token')
    expect(token).to be_present

    post "/v1/public/events/#{event.slug}/exhibitor_access_sessions", params: { challenge: challenge }
    expect(response).to have_http_status(:unprocessable_content)

    other_event = create(:event, status: :published)
    get "/v1/public/events/#{other_event.slug}/exhibitor_access_session", headers: { 'Authorization' => "Bearer #{token}" }
    expect(response).to have_http_status(:unauthorized)
    expect(access.reload.challenge_consumed_at).to be_present
  end
end
