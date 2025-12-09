require 'rails_helper'

RSpec.describe 'V1::RentableItems', type: :request do
  let(:user) { create(:user) }
  let(:item_category) { create(:item_category) }



  path '/v1/rentable_items' do
    get('list rentable items') do
      tags 'Rentable Items'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          let!(:rentable_item1) { create(:rentable_item, item_category: item_category) }
          let!(:rentable_item2) { create(:rentable_item, item_category: item_category) }
          before { get v1_rentable_items_path, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let!(:rentable_item1) { create(:rentable_item, item_category: item_category) }
          let!(:rentable_item2) { create(:rentable_item, item_category: item_category) }
          before { get v1_rentable_items_path, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          let!(:other_rentable_item1) { create(:rentable_item, item_category: item_category) } # Owned by a different user
          let!(:other_rentable_item2) { create(:rentable_item, item_category: item_category) } # Owned by a different user
          let!(:contractor_rentable_item) { create(:rentable_item, item_category: item_category, user: user) }

          before { get v1_rentable_items_path, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data.count).to eq(1)
            expect(data.first['id']).to eq(contractor_rentable_item.id)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { get v1_rentable_items_path, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data).to be_empty
          end
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { nil }
        before { get v1_rentable_items_path, headers: {} }
        it 'returns a 401 response' do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    post('create rentable item') do
      tags 'Rentable Items'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :rentable_item, in: :body, schema: {
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

      let(:rentable_item) do
        {
          rentable_item: {
            name: 'New Rentable Item',
            description: 'A description',
            unit_of_measure: 'unit',
            default_price: 100.00,
            status: 'active',
            item_category_id: item_category.id
          }
        }
      end

      response(201, 'created') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          before { post v1_rentable_items_path, params: rentable_item, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
            data = JSON.parse(response.body)
            expect(data['name']).to eq('New Rentable Item')
            expect(data['user_id']).to eq(user.id)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          before { post v1_rentable_items_path, params: rentable_item, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
          end
        end

        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          before { post v1_rentable_items_path, params: rentable_item, headers: auth_headers(user) }
          it 'returns a 201 response' do
            expect(response).to have_http_status(:created)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          before { post v1_rentable_items_path, params: rentable_item, headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end

  path '/v1/rentable_items/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    let(:rentable_item_record) { create(:rentable_item, item_category: item_category, user: item_creator) }
    let(:id) { rentable_item_record.id }

    get('show rentable item') do
      tags 'Rentable Items'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          let(:item_creator) { create(:user) }
          before { get v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:item_creator) { create(:user) }
          before { get v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as the exhibition contractor who created the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { user }
          before { get v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { create(:user) }
          before { get v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:item_creator) { create(:user) }
          before { get v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    patch('update rentable item') do
      tags 'Rentable Items'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :rentable_item, in: :body, schema: {
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

      let(:rentable_item) { { rentable_item: { name: 'Updated Name' } } }

      response(200, 'successful') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          let(:item_creator) { create(:user) }
          before { patch v1_rentable_item_path(id: id), params: rentable_item, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
            data = JSON.parse(response.body)
            expect(data['name']).to eq('Updated Name')
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:item_creator) { create(:user) }
          before { patch v1_rentable_item_path(id: id), params: rentable_item, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end

        context 'as the exhibition contractor who created the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { user }
          before { patch v1_rentable_item_path(id: id), params: rentable_item, headers: auth_headers(user) }
          it 'returns a 200 response' do
            expect(response).to have_http_status(:ok)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { create(:user) }
          before { patch v1_rentable_item_path(id: id), params: rentable_item, headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:item_creator) { create(:user) }
          before { patch v1_rentable_item_path(id: id), params: rentable_item, headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end

    delete('delete rentable item') do
      tags 'Rentable Items'
      produces 'application/json'
      security [bearerAuth: []]

      response(204, 'no content') do
        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          let(:item_creator) { create(:user) }
          before { delete v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:item_creator) { create(:user) }
          before { delete v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end

        context 'as the exhibition contractor who created the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { user }
          before { delete v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 204 response' do
            expect(response).to have_http_status(:no_content)
          end
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { create(:user) }
          before { delete v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:item_creator) { create(:user) }
          before { delete v1_rentable_item_path(id: id), headers: auth_headers(user) }
          it 'returns a 403 response' do
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end
end
