require 'swagger_helper'

RSpec.describe 'V1::EventPrintingServices', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:api_key) { create(:api_key, user: org_owner) }
  let(:auth_header) { { 'Authorization' => api_key.raw_key } }
  let(:event) { create(:event, use_exhibitor_kit: true, enable_exhibitor_management: true) }
  let(:event_id) { event.id }
  let(:printing_service) { create(:printing_service) } # Global printing service
  let!(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) }

  path '/v1/events/{event_id}/event_printing_services' do
    parameter name: 'event_id', in: :path, type: :string, description: 'event_id'

    get('list event printing services') do
      tags 'Event Printing Services'
      produces 'application/json'
      security [{ api_key: [] }]

      response(200, 'successful') do
        before { get v1_event_event_printing_services_path(event_id: event_id), headers: auth_header }

        it 'returns a 200 response with event printing services' do
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data.first['id']).to eq(event_printing_service.id)
          expect(data.first).to have_key('printing_service')
          expect(data.first['printing_service']).to have_key('image_url')
        end
      end

      response(200, 'successful for org owner when exhibitor management is disabled') do
        let(:event) { create(:event, use_exhibitor_kit: true, enable_exhibitor_management: false) }
        let(:event_id) { event.id }

        before { get v1_event_event_printing_services_path(event_id: event_id), headers: auth_header }

        it 'returns a 200 response' do
          expect(response).to have_http_status(:ok)
        end
      end

      response(401, 'unauthorized') do
        before do
          get v1_event_event_printing_services_path(event_id: event_id),
              headers: { 'Authorization' => 'invalid_key_string' }
        end
        it 'returns a 401 response' do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end
  end

  path '/v1/events/{event_id}/event_printing_services/{id}' do
    parameter name: 'event_id', in: :path, type: :string, description: 'event_id'
    parameter name: 'id', in: :path, type: :string, description: 'id'

    get('show event printing service') do
      tags 'Event Printing Services'
      produces 'application/json'
      security [{ api_key: [] }]

      response(200, 'successful') do
        before do
          get v1_event_event_printing_service_path(event_id: event_id, id: event_printing_service.id),
              headers: auth_header
        end

        it 'returns a 200 response with the event printing service' do
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['id']).to eq(event_printing_service.id)
        end
      end

      response(200, 'successful for org owner when exhibitor management is disabled') do
        let(:event) { create(:event, use_exhibitor_kit: true, enable_exhibitor_management: false) }
        let(:event_id) { event.id }
        let!(:event_printing_service) do
          create(:event_printing_service, event: event, printing_service: printing_service)
        end

        before do
          get v1_event_event_printing_service_path(event_id: event_id, id: event_printing_service.id),
              headers: auth_header
        end

        it 'returns a 200 response' do
          expect(response).to have_http_status(:ok)
        end
      end
    end

    delete('delete event printing service') do
      tags 'Event Printing Services'
      produces 'application/json'
      security [{ api_key: [] }]

      response(204, 'no content') do
        before do
          delete v1_event_event_printing_service_path(event_id: event_id, id: event_printing_service.id),
                 headers: auth_header
        end

        it 'deletes the event printing service' do
          expect(response).to have_http_status(:no_content)
          expect(EventPrintingService.find_by(id: event_printing_service.id)).to be_nil
        end
      end

      response(204, 'successful delete for org owner when exhibitor management is disabled') do
        let(:event) { create(:event, use_exhibitor_kit: true, enable_exhibitor_management: false) }
        let(:event_id) { event.id }
        let!(:event_printing_service) do
          create(:event_printing_service, event: event, printing_service: printing_service)
        end

        before do
          delete v1_event_event_printing_service_path(event_id: event_id, id: event_printing_service.id),
                 headers: auth_header
        end

        it 'returns a 204 response' do
          expect(response).to have_http_status(:no_content)
        end
      end
    end
  end
end
