require 'rails_helper'

RSpec.describe 'V1 PeopleCounterConnections', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let!(:event) do
    create(:event, published: false).tap do |e|
      create(:event_assignment, role: :event_admin, event: e, user: organizer)
    end
  end
  let(:base) { "/v1/events/#{event.id}/people_counter_connection" }
  let(:valid) { { people_counter_connection: { base_url: 'https://counter.test/', api_key: 'cz_secretkey1234' } } }

  describe 'org-owner-only access' do
    it 'forbids an organizer on every action' do
      get base, headers: auth_headers(organizer)
      expect(response).to have_http_status(:forbidden)

      put base, params: valid, headers: auth_headers(organizer)
      expect(response).to have_http_status(:forbidden)

      delete base, headers: auth_headers(organizer)
      expect(response).to have_http_status(:forbidden)

      post "#{base}/test", params: valid, headers: auth_headers(organizer)
      expect(response).to have_http_status(:forbidden)
      expect(PeopleCounterConnection.count).to eq(0)
    end

    it 'requires authentication' do
      get base
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET show' do
    it 'reports an unconfigured event' do
      get base, headers: auth_headers(org_owner)

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('configured' => false, 'source' => nil, 'base_url' => nil, 'key_prefix' => nil)
    end

    it 'shows the URL and key prefix, never the key' do
      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey1234')
      get base, headers: auth_headers(org_owner)

      expect(json_response).to eq('configured' => true, 'source' => 'event', 'base_url' => 'https://counter.test', 'key_prefix' => 'cz_secre')
      expect(response.body).not_to include('secretkey1234')
    end
  end

  describe 'PUT update' do
    it 'saves a connection, trimming the trailing slash, with the key encrypted at rest' do
      put base, params: valid, headers: auth_headers(org_owner)

      expect(response).to have_http_status(:ok)
      connection = event.reload.people_counter_connection
      expect(connection).to have_attributes(base_url: 'https://counter.test', api_key: 'cz_secretkey1234')
      expect(PeopleCounterConnection.connection.select_value('SELECT api_key FROM people_counter_connections')).not_to include('secretkey1234')
      expect(response.body).not_to include('secretkey1234')
    end

    it 'requires a URL and a key' do
      put base, params: { people_counter_connection: { base_url: '', api_key: '' } }, headers: auth_headers(org_owner)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'keeps the saved key when the key is left blank and the URL is unchanged' do
      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey1234')

      put base, params: { people_counter_connection: { base_url: 'https://counter.test', api_key: '' } },
                headers: auth_headers(org_owner)

      expect(response).to have_http_status(:ok)
      expect(event.reload.people_counter_connection.api_key).to eq('cz_secretkey1234')
    end

    it 'refuses to move the saved key to a new URL without retyping the key' do
      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey1234')

      put base, params: { people_counter_connection: { base_url: 'https://evil.test', api_key: '' } },
                headers: auth_headers(org_owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(event.reload.people_counter_connection.base_url).to eq('https://counter.test')
    end
  end

  describe 'DELETE destroy' do
    it 'removes the connection' do
      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey1234')

      delete base, headers: auth_headers(org_owner)

      expect(response).to have_http_status(:no_content)
      expect(event.reload.people_counter_connection).to be_nil
    end
  end

  describe 'POST test' do
    before { allow(PeopleCounter::Client).to receive(:guard?).and_return(false) }

    it 'reports success with the number of counters found' do
      stub_request(:get, 'https://counter.test/api/v1/venues')
        .with(headers: { 'Authorization' => 'Bearer cz_secretkey1234' })
        .to_return(body: { data: [{ id: 1, name: 'A' }, { id: 2, name: 'B' }] }.to_json)

      post "#{base}/test", params: valid, headers: auth_headers(org_owner)

      expect(response).to have_http_status(:ok)
      expect(json_response).to eq('ok' => true, 'venues' => 2)
    end

    it 'says so when the counter service rejects the key (200, never 401, so the panel keeps the session)' do
      stub_request(:get, 'https://counter.test/api/v1/venues').to_return(status: 401)

      post "#{base}/test", params: valid, headers: auth_headers(org_owner)

      expect(response).to have_http_status(:ok)
      expect(json_response).to include('ok' => false, 'reason' => 'unauthorized')
    end

    it 'says so when the service is unreachable' do
      stub_request(:get, 'https://counter.test/api/v1/venues').to_timeout

      post "#{base}/test", params: valid, headers: auth_headers(org_owner)

      expect(json_response).to include('ok' => false, 'reason' => 'unreachable')
    end

    it 'tests the saved connection when nothing is typed' do
      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey1234')
      stub_request(:get, 'https://counter.test/api/v1/venues')
        .with(headers: { 'Authorization' => 'Bearer cz_secretkey1234' })
        .to_return(body: { data: [] }.to_json)

      post "#{base}/test", headers: auth_headers(org_owner)

      expect(json_response).to eq('ok' => true, 'venues' => 0)
    end

    it 'never sends the saved key to a different URL' do
      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey1234')

      post "#{base}/test", params: { people_counter_connection: { base_url: 'https://evil.test', api_key: '' } },
                           headers: auth_headers(org_owner)

      expect(response).to have_http_status(:unprocessable_content)
      expect(WebMock).not_to have_requested(:get, /evil\.test/)
    end
  end
end
