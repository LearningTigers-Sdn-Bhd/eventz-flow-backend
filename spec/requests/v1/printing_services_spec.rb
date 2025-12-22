require 'rails_helper'

RSpec.describe 'V1::PrintingServices', type: :request do
  let(:user) { create(:user) }
  let(:item_category) { create(:item_category) }



  path '/v1/printing_services' do
    get('list printing services') do
      tags 'Printing Services'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          let!(:printing_service1) { create(:printing_service, item_category: item_category) }
          let!(:printing_service2) { create(:printing_service, item_category: item_category) }
          before { get v1_printing_services_path, headers: auth_headers(user) }
          it 'returns a 200 response with image_url' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
            expect(data.first).to have_key('image_url')
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let!(:printing_service1) { create(:printing_service, item_category: item_category) }
          let!(:printing_service2) { create(:printing_service, item_category: item_category) }
          before { get v1_printing_services_path, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          let!(:other_printing_service1) { create(:printing_service, item_category: item_category) } # Owned by a different user
          let!(:other_printing_service2) { create(:printing_service, item_category: item_category) } # Owned by a different user
          let!(:contractor_printing_service) { create(:printing_service, item_category: item_category, user: user) }

          before { get v1_printing_services_path, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data.count).to eq(1)
            expect(data.first['id']).to eq(contractor_printing_service.id)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { get v1_printing_services_path, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data).to be_empty
          end
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { nil }
        before { get v1_printing_services_path, headers: {} }
        it 'returns a 401 response' do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    post('create printing service') do
      tags 'Printing Services'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :printing_service, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          unit_of_measure: { type: :string },
          default_price: { type: :number, format: :float },
          status: { type: :string, enum: %w[active inactive] },
          item_category_id: { type: :integer }
        },
        required: %w[name unit_of_measure default_price status item_category_id]
      }

      let(:printing_service) do
        {
          printing_service: {
            name: 'New Printing Service',
            description: 'A description',
            unit_of_measure: 'page',
            default_price: 50.00,
            status: 'active',
            item_category_id: item_category.id
          }
        }
      end

      response(201, 'created') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          before { post v1_printing_services_path, params: printing_service, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
            data = JSON.parse(response.body)
            expect(data['name']).to eq('New Printing Service')
            expect(data['user_id']).to eq(user.id)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          before { post v1_printing_services_path, params: printing_service, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
          end
        end

        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          before { post v1_printing_services_path, params: printing_service, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { post v1_printing_services_path, params: printing_service, headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end

  path '/v1/printing_services/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    let(:printing_service_record) { create(:printing_service, item_category: item_category, user: service_creator) }
    let(:id) { printing_service_record.id }

    get('show printing service') do
      tags 'Printing Services'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          let(:service_creator) { create(:user) }
          before { get v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:service_creator) { create(:user) }
          before { get v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as the exhibition contractor who created the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { user }
          before { get v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { create(:user) }
          before { get v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:service_creator) { create(:user) }
          before { get v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    patch('update printing service') do
      tags 'Printing Services'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :printing_service, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          unit_of_measure: { type: :string },
          default_price: { type: :number, format: :float },
          status: { type: :string, enum: %w[active inactive] },
          item_category_id: { type: :integer }
        }
      }

      let(:printing_service) { { printing_service: { name: 'Updated Printing Service Name' } } }

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          let(:service_creator) { create(:user) }
          before { patch v1_printing_service_path(id: id), params: printing_service, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data['name']).to eq('Updated Printing Service Name')
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:service_creator) { create(:user) }
          before { patch v1_printing_service_path(id: id), params: printing_service, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as the exhibition contractor who created the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { user }
          before { patch v1_printing_service_path(id: id), params: printing_service, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { create(:user) }
          before { patch v1_printing_service_path(id: id), params: printing_service, headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:service_creator) { create(:user) }
          before { patch v1_printing_service_path(id: id), params: printing_service, headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    delete('delete printing service') do
      tags 'Printing Services'
      produces 'application/json'
      security [bearerAuth: []]

      response(204, 'no content') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          let(:service_creator) { create(:user) }
          before { delete v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:service_creator) { create(:user) }
          before { delete v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end

        context 'as the exhibition contractor who created the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { user }
          before { delete v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { create(:user) }
          before { delete v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:service_creator) { create(:user) }
          before { delete v1_printing_service_path(id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end
end
