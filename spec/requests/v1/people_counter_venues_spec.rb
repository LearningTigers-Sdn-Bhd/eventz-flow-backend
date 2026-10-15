require 'rails_helper'

RSpec.describe 'V1 PeopleCounterVenues', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let!(:event) do
    create(:event, published: false).tap do |e|
      create(:event_assignment, role: :event_admin, event: e, user: organizer)
    end
  end
  let(:path) { "/v1/events/#{event.id}/people_counter/venues" }
  let(:venues_url) { 'https://counter.test/api/v1/venues' }

  before do
    allow(PeopleCounter::Client).to receive(:guard?).and_return(false)
    PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey1234')
  end

  it "lists the venues from the event's own connection, without counts" do
    stub_request(:get, venues_url).with(headers: { 'Authorization' => 'Bearer cz_secretkey1234' }).to_return(
      body: { data: [{ id: 1, name: 'Hall A', capacity: 100, today: { in: 5, out: 1, occupancy: 4 } }] }.to_json
    )

    get path, headers: auth_headers(org_owner)

    expect(response).to have_http_status(:ok)
    expect(json_response).to eq([{ 'id' => 1, 'name' => 'Hall A', 'capacity' => 100 }])
  end

  it 'forbids an organizer' do
    get path, headers: auth_headers(organizer)
    expect(response).to have_http_status(:forbidden)
  end

  it 'requires authentication' do
    get path
    expect(response).to have_http_status(:unauthorized)
  end

  it 'returns 503 when the counter service is down' do
    stub_request(:get, venues_url).to_timeout
    get path, headers: auth_headers(org_owner)
    expect(response).to have_http_status(:service_unavailable)
  end

  it 'returns 503, never 401, when the counter service rejects the key (a 401 would log the panel out)' do
    stub_request(:get, venues_url).to_return(status: 401)
    get path, headers: auth_headers(org_owner)
    expect(response).to have_http_status(:service_unavailable)
  end

  it 'returns 503 when the event has no connection and nothing is configured server-wide' do
    event.people_counter_connection.destroy
    get path, headers: auth_headers(org_owner)
    expect(response).to have_http_status(:service_unavailable)
  end
end
