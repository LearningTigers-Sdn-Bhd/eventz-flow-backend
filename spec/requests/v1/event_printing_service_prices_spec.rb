require 'rails_helper'

RSpec.describe 'V1::EventPrintingServicePrices', type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:printing_service) { create(:printing_service) }
  let(:event_printing_service) { create(:event_printing_service, event: event, printing_service: printing_service) }

  path '/v1/event_printing_services/{event_printing_service_id}/event_printing_service_prices' do
    parameter name: 'event_printing_service_id', in: :path, type: :string, description: 'event_printing_service_id'

    get('list event printing service prices') do
      tags 'Event Printing Service Prices'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:event_printing_service_id) { event_printing_service.id }
        let!(:price_tier1) { create(:event_printing_service_price_tier, event_printing_service: event_printing_service) }
        let!(:price_tier2) { create(:event_printing_service_price_tier, event_printing_service: event_printing_service) }

        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          before { get v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          before { get v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          before { get v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as an exhibition contractor for the event' do
          let(:user) { create(:user, :exhibition_contractor, with_profile: false) }
          let!(:contractor_profile) { create(:exhibition_contractor_profile, user: user) }
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          before { get v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { get v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data).to be_empty
          end
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { nil }
        let(:event_printing_service_id) { event_printing_service.id }
        before { get v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), headers: {} }
        it 'returns a 401 response' do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    post('create event printing service price') do
      tags 'Event Printing Service Prices'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :event_printing_service_price_tier, in: :body, schema: {
        type: :object,
        properties: {
          price: { type: :number, format: :float },
          start_date: { type: :string, format: 'date-time' },
          end_date: { type: :string, format: 'date-time' },
          label: { type: :string }
        },
        required: %w[price start_date label]
      }

      let(:event_printing_service_id) { event_printing_service.id }
      let(:event_printing_service_price_tier) do
        {
          event_printing_service_price_tier: {
            price: 250.00,
            start_date: Time.current.iso8601,
            end_date: (Time.current + 1.month).iso8601,
            label: 'Standard'
          }
        }
      end

      response(201, 'created') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          before { post v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          before { post v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
          end
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          before { post v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
          end
        end

        context 'as an exhibition contractor for the event' do # New context
          let(:user) { create(:user, :exhibition_contractor, with_profile: true) } # Ensure profile exists
          let!(:contractor_profile) { user.reload.exhibition_contractor_profile } # Use the one created with the user
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          before { post v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { post v1_event_printing_service_event_printing_service_prices_path(event_printing_service_id: event_printing_service_id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end

  path '/v1/event_printing_services/{event_printing_service_id}/event_printing_service_prices/{id}' do
    parameter name: 'event_printing_service_id', in: :path, type: :string, description: 'event_printing_service_id'
    parameter name: 'id', in: :path, type: :string, description: 'id'

    let(:event_printing_service_id) { event_printing_service.id }
    let!(:price_tier_record) { create(:event_printing_service_price_tier, event_printing_service: event_printing_service) }
    let(:id) { price_tier_record.id }

    get('show event printing service price') do
      tags 'Event Printing Service Prices'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          before { get v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          before { get v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          before { get v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as an exhibition contractor for the event' do
          let(:user) { create(:user, :exhibition_contractor, with_profile: false) }
          let!(:contractor_profile) { create(:exhibition_contractor_profile, user: user) }
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          before { get v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { get v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    patch('update event printing service price') do
      tags 'Event Printing Service Prices'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :event_printing_service_price_tier, in: :body, schema: {
        type: :object,
        properties: {
          price: { type: :number, format: :float },
          end_date: { type: :string, format: 'date-time' }
        }
      }

      let(:event_printing_service_price_tier) { { event_printing_service_price_tier: { price: 300.00, end_date: (Time.current + 2.months).iso8601 } } }

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          before { patch v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          before { patch v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          before { patch v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as an exhibition contractor for the event' do # New context
          let(:user) { create(:user, :exhibition_contractor, with_profile: true) } # Ensure profile exists
          let!(:contractor_profile) { user.reload.exhibition_contractor_profile } # Use the one created with the user
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          before { patch v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { patch v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), params: event_printing_service_price_tier, headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    delete('delete event printing service price') do
      tags 'Event Printing Service Prices'
      produces 'application/json'
      security [bearerAuth: []]

      response(204, 'no content') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          before { delete v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          before { delete v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end

        context 'as event staff for the event' do
          let(:user) { create(:user) }
          let!(:event_assignment) { create(:event_assignment, user: user, event: event, role: :event_admin) }
          before { delete v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end

        context 'as an exhibition contractor for the event' do # New context
          let(:user) { create(:user, :exhibition_contractor, with_profile: true) } # Ensure profile exists
          let!(:contractor_profile) { user.reload.exhibition_contractor_profile } # Use the one created with the user
          let!(:event_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: contractor_profile) }
          before { delete v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { delete v1_event_printing_service_event_printing_service_price_path(event_printing_service_id: event_printing_service_id, id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end
end
