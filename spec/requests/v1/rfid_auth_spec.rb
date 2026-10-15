require 'rails_helper'

# Plan 5 Task 2: an RFID key is a device key. It reaches the seven device
# routes and nothing else, and the ordinary scopes are untouched by it.
RSpec.describe 'V1::Rfid authentication', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_api_access: true) }
  let!(:rfid_key) { create(:api_key, user: owner, event: event, scope: 'rfid') }

  it 'forbids an RFID key on an existing event route' do
    get "/v1/events/#{event.id}", headers: { 'Authorization' => rfid_key.raw_key }

    expect(response).to have_http_status(:forbidden)
    expect(json['success']).to be(false)
  end

  it 'forbids an RFID key on the recent check-ins route' do
    get '/v1/scan/recent_check_ins', headers: { 'Authorization' => rfid_key.raw_key }

    expect(response).to have_http_status(:forbidden)
  end

  it 'rejects a revoked RFID key on an existing event route' do
    rfid_key.revoke!

    get "/v1/events/#{event.id}", headers: { 'Authorization' => rfid_key.raw_key }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'leaves ordinary event keys working on ordinary routes' do
    key = create(:api_key, user: owner, event: event, scope: 'read_write')

    get "/v1/events/#{event.id}", headers: { 'Authorization' => key.raw_key }

    expect(response).to have_http_status(:ok)
  end

  it 'lets an org owner mint an rfid key and keeps organizers at read_only' do
    organizer = create(:user, :organizer)

    post "/v1/events/#{event.id}/api_keys",
         params: { name: 'Desk A', scope: 'rfid' },
         headers: auth_headers(owner), as: :json
    expect(response).to have_http_status(:created)
    expect(json['scope']).to eq('rfid')
    expect(json['raw_key'].to_s).to start_with('rfd_')

    post "/v1/events/#{event.id}/api_keys",
         params: { name: 'Desk B', scope: 'rfid' },
         headers: auth_headers(organizer), as: :json
    expect(response).to have_http_status(:created)
    expect(json['scope']).to eq('read_only')
  end
end
