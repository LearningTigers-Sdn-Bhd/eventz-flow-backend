require 'swagger_helper'

RSpec.describe 'V1::EventRentableItems', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:api_key) { create(:api_key, user: org_owner) }
  let(:auth_header) { { 'Authorization' => api_key.raw_key } }
  let(:event) { create(:event, use_exhibitor_kit: true) }
  let(:event_id) { event.id }
  let(:rentable_item) { create(:rentable_item) } # Global rentable item
  let!(:event_rentable_item) { create(:event_rentable_item, event: event, rentable_item: rentable_item) }

  path '/v1/events/{event_id}/event_rentable_items' do
    parameter name: 'event_id', in: :path, type: :string, description: 'event_id'

    get('list event rentable items') do
      tags 'Event Rentable Items'
      produces 'application/json'
      security [api_key: []]

      response(200, 'successful') do
        before { get v1_event_event_rentable_items_path(event_id: event_id), headers: auth_header }

        it 'returns a 200 response with event rentable items' do
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data.first['id']).to eq(event_rentable_item.id)
          expect(data.first).to have_key('rentable_item')
          expect(data.first['rentable_item']).to have_key('image_url')
        end
      end

      response(401, 'unauthorized') do
        before { get v1_event_event_rentable_items_path(event_id: event_id), headers: { 'Authorization' => 'invalid_key_string' } }
        it 'returns a 401 response' do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  path '/v1/events/{event_id}/event_rentable_items/{id}' do
    parameter name: 'event_id', in: :path, type: :string, description: 'event_id'
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('show event rentable item') do
      tags 'Event Rentable Items'
      produces 'application/json'
      security [api_key: []]

      response(200, 'successful') do
        before { get v1_event_event_rentable_item_path(event_id: event_id, id: event_rentable_item.id), headers: auth_header }
        it 'returns a 200 response with the event rentable item' do
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['id']).to eq(event_rentable_item.id)
        end
      end
    end

    delete('delete event rentable item') do
      tags 'Event Rentable Items'
      produces 'application/json'
      security [api_key: []]

      response(204, 'no content') do
        before { delete v1_event_event_rentable_item_path(event_id: event_id, id: event_rentable_item.id), headers: auth_header }

        it 'deletes the event rentable item' do
          expect(response).to have_http_status(:no_content)
          expect(EventRentableItem.find_by(id: event_rentable_item.id)).to be_nil
        end
      end
    end
  end
end
