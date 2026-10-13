require 'rails_helper'

# Org owners set halls up; organizers (and other event staff) can only view them.
RSpec.describe 'V1 EventHalls', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:outsider) { create(:user, :member) }
  let!(:event) do
    create(:event, published: false).tap do |e|
      create(:event_assignment, role: :event_admin, event: e, user: organizer)
    end
  end
  let!(:hall) { create(:event_hall, event: event, name: 'Hall A', floor: 'Level 1') }
  let(:base) { "/v1/events/#{event.id}/event_halls" }

  describe 'GET index' do
    it 'lets an organizer see the event halls' do
      create(:event_hall, name: 'Other event hall')
      get base, headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      expect(json_response.map { |h| h['name'] }).to eq(['Hall A'])
    end

    it 'requires authentication' do
      get base
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET headcount' do
    it 'lets an organizer see the rollup' do
      hall.update!(counter_venue_id: nil)
      get "#{base}/headcount", headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      expect(json_response['halls'].map { |h| h['status'] }).to eq(['unlinked'])
      expect(json_response.keys).to include('configured', 'event', 'levels', 'halls', 'generated_at')
    end

    it 'says whether a counter connection exists' do
      get "#{base}/headcount", headers: auth_headers(organizer)
      expect(json_response['configured']).to be(false)

      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey')
      get "#{base}/headcount", headers: auth_headers(organizer)
      expect(json_response['configured']).to be(true)
    end

    it 'forbids a user without access to the event' do
      get "#{base}/headcount", headers: auth_headers(outsider)
      expect(response).to have_http_status(:forbidden)
    end

    it 'requires authentication' do
      get "#{base}/headcount"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET analytics' do
    before { hall.update!(counter_venue_id: nil) }

    it 'lets an organizer read the day, with the event days listed' do
      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey')
      get "#{base}/analytics", headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      expect(json_response.keys).to include('date', 'days', 'bucket', 'configured', 'event', 'levels', 'halls')
      expect(json_response['halls'].map { |h| h['status'] }).to eq(['unlinked'])
    end

    it 'returns an empty, unconfigured day when the event has no counter connection' do
      get "#{base}/analytics", headers: auth_headers(organizer)

      expect(json_response).to include('configured' => false, 'halls' => [], 'levels' => [])
    end

    it 'forbids a user without access to the event' do
      get "#{base}/analytics", headers: auth_headers(outsider)
      expect(response).to have_http_status(:forbidden)
    end

    it 'requires authentication' do
      get "#{base}/analytics"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET daily' do
    it 'lets an organizer read the day-by-day summary' do
      PeopleCounterConnection.create!(event: event, base_url: 'https://counter.test', api_key: 'cz_secretkey')
      allow_any_instance_of(PeopleCounter::Client).to receive(:venue_series).and_return([]) # rubocop:disable RSpec/AnyInstance
      get "#{base}/daily", headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      expect(json_response.keys).to include('configured', 'days')
    end

    it 'forbids a user without access to the event' do
      get "#{base}/daily", headers: auth_headers(outsider)
      expect(response).to have_http_status(:forbidden)
    end

    it 'requires authentication' do
      get "#{base}/daily"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET analytics_export' do
    it 'downloads an Excel workbook' do
      get "#{base}/analytics_export", headers: auth_headers(organizer)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(response.body.byteslice(0, 2)).to eq('PK') # an .xlsx is a zip
      expect(response.headers['Content-Disposition']).to include("people-counts-#{event.id}-", '.xlsx')
    end

    it 'forbids a user without access to the event' do
      get "#{base}/analytics_export", headers: auth_headers(outsider)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST create' do
    let(:params) { { event_hall: { name: 'Hall B', floor: 'Level 2', counter_venue_id: 7 } } }

    it 'lets an org owner add a hall and link a counter' do
      expect { post base, params: params, headers: auth_headers(org_owner) }
        .to change(event.event_halls, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json_response).to include('name' => 'Hall B', 'floor' => 'Level 2', 'counter_venue_id' => 7)
    end

    it 'rejects a duplicate name in the same event' do
      post base, params: { event_hall: { name: 'Hall A' } }, headers: auth_headers(org_owner)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'forbids an organizer, even an event admin' do
      expect { post base, params: params, headers: auth_headers(organizer) }.not_to change(EventHall, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it 'forbids a user without access to the event' do
      expect { post base, params: params, headers: auth_headers(outsider) }.not_to change(EventHall, :count)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH update' do
    it 'lets an org owner link the hall to a counter venue and rename it' do
      patch "#{base}/#{hall.id}", params: { event_hall: { name: 'Hall Z', counter_venue_id: 42 } },
                                  headers: auth_headers(org_owner)

      expect(response).to have_http_status(:ok)
      expect(hall.reload).to have_attributes(name: 'Hall Z', counter_venue_id: 42)
    end

    it 'forbids an organizer from changing anything, including the link' do
      hall.update!(counter_venue_id: 42)

      patch "#{base}/#{hall.id}", params: { event_hall: { counter_venue_id: 99 } }, headers: auth_headers(organizer)
      expect(response).to have_http_status(:forbidden)

      patch "#{base}/#{hall.id}", params: { event_hall: { name: 'Renamed' } }, headers: auth_headers(organizer)
      expect(response).to have_http_status(:forbidden)
      expect(hall.reload).to have_attributes(name: 'Hall A', counter_venue_id: 42)
    end

    it 'cannot reach a hall through another event' do
      other = create(:event_hall)
      patch "#{base}/#{other.id}", params: { event_hall: { name: 'x' } }, headers: auth_headers(org_owner)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE destroy' do
    it 'lets an org owner remove the hall' do
      expect { delete "#{base}/#{hall.id}", headers: auth_headers(org_owner) }
        .to change(EventHall, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it 'forbids an organizer and a user without access' do
      delete "#{base}/#{hall.id}", headers: auth_headers(organizer)
      expect(response).to have_http_status(:forbidden)

      delete "#{base}/#{hall.id}", headers: auth_headers(outsider)
      expect(response).to have_http_status(:forbidden)
      expect(EventHall.exists?(hall.id)).to be(true)
    end
  end
end
