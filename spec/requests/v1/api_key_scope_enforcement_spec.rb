require 'rails_helper'

# Verifies that an event-scoped API key with scope=read_only can fetch event
# data (GET) but cannot perform write requests (POST/PATCH/DELETE) — and that
# scope=read_write keys retain full CRUD.
RSpec.describe 'API key method scope enforcement', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event)     { create(:event, user: org_owner, use_api_access: true) }

  let(:read_only_key) do
    key = org_owner.api_keys.create!(name: 'RO', event: event, scope: 'read_only')
    key
  end

  let(:read_write_key) do
    key = org_owner.api_keys.create!(name: 'RW', event: event, scope: 'read_write')
    key
  end

  describe 'GET /v1/events/:id' do
    it 'allows a read_only key' do
      get "/v1/events/#{event.id}", headers: { 'Authorization' => read_only_key.raw_key }
      expect(response).to have_http_status(:ok)
    end

    it 'allows a read_write key' do
      get "/v1/events/#{event.id}", headers: { 'Authorization' => read_write_key.raw_key }
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'write requests with a read_only key' do
    it 'rejects PATCH /v1/events/:id' do
      patch "/v1/events/#{event.id}",
            params: { event: { title: 'Renamed' } }.to_json,
            headers: {
              'Authorization' => read_only_key.raw_key,
              'Content-Type'  => 'application/json'
            }

      expect(response).to have_http_status(:forbidden)
      expect(JSON.parse(response.body)['message']).to include('read-only')
      expect(event.reload.title).not_to eq('Renamed')
    end

    it 'rejects DELETE /v1/events/:id' do
      delete "/v1/events/#{event.id}", headers: { 'Authorization' => read_only_key.raw_key }
      expect(response).to have_http_status(:forbidden)
      expect(Event.exists?(event.id)).to be true
    end
  end
end
