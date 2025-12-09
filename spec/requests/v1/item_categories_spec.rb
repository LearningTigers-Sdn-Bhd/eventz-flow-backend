require 'swagger_helper'

RSpec.describe 'V1::ItemCategories', type: :request do
  let(:item_category) { create(:item_category) }

  path '/v1/item_categories' do
    get('list item categories') do
      tags 'Item Categories'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let!(:item_category1) { create(:item_category) }
        let!(:item_category2) { create(:item_category) }
        let(:user) { create(:user, :org_owner) } # Admin can view all

        it 'returns a 200 response with all item categories' do
          get v1_item_categories_path, headers: auth_headers(user)
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data.count).to eq(2)
          expect(data.map { |ic| ic['id'] }).to match_array([item_category1.id, item_category2.id])
        end
      end

      response(401, 'unauthorized') do
        it 'returns a 401 response' do
          get v1_item_categories_path, headers: {} # Pass empty headers
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response(403, 'forbidden') do
        let(:user) { create(:user, :member) } # Regular user forbidden
        it 'returns a 403 response' do
          get v1_item_categories_path, headers: auth_headers(user)
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    post('create item category') do
      tags 'Item Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :item_category, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'New Category' },
          active: { type: :boolean, example: true }
        },
        required: %w[name active]
      }

      let(:item_category_params) { { item_category: { name: 'New Category', active: true } } }

      response(201, 'created') do
        let(:user) { create(:user, :org_owner) } # Admin can create
        before { post v1_item_categories_path, params: item_category_params, headers: auth_headers(user) }

        it 'creates a new item category and returns 201' do
          expect(response).to have_http_status(:created)
          data = JSON.parse(response.body)
          expect(data['name']).to eq('New Category')
          expect(ItemCategory.last.name).to eq('New Category')
        end
      end

      response(401, 'unauthorized') do
        let(:user) { nil } # No user
        it 'returns a 401 response' do
          post v1_item_categories_path, params: item_category_params, headers: {} # Pass empty headers
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response(403, 'forbidden') do
        let(:user) { create(:user, :member) } # Regular user forbidden
        it 'returns a 403 response' do
          post v1_item_categories_path, params: item_category_params, headers: auth_headers(user)
          expect(response).to have_http_status(:forbidden)
        end
      end

      response(422, 'unprocessable entity') do
        let(:user) { create(:user, :org_owner) } # Admin with invalid data
        let(:item_category_params) { { item_category: { name: '', active: true } } } # Invalid name
        it 'returns a 422 response' do
          post v1_item_categories_path, params: item_category_params, headers: auth_headers(user)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end
  end

  path '/v1/item_categories/{id}' do
    parameter name: 'id', in: :path, type: :string, description: 'id'

    let(:item_category_record) { create(:item_category) }
    let(:id) { item_category_record.id }

    get('show item category') do
      tags 'Item Categories'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:user) { create(:user, :org_owner) } # Admin can view
        before { get v1_item_category_path(id: id), headers: auth_headers(user) }

        it 'returns a 200 response with the item category' do
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['id']).to eq(item_category_record.id)
        end
      end

      response(401, 'unauthorized') do
        it 'returns a 401 response' do
          get v1_item_category_path(id: id), headers: {} # Pass empty headers
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response(403, 'forbidden') do
        let(:user) { create(:user, :member) } # Regular user forbidden
        it 'returns a 403 response' do
          get v1_item_category_path(id: id), headers: auth_headers(user)
          expect(response).to have_http_status(:forbidden)
        end
      end

      response(404, 'not found') do
        let(:id) { 0 } # Non-existent ID
        let(:user) { create(:user, :org_owner) }
        it 'returns a 404 response' do
          get v1_item_category_path(id: id), headers: auth_headers(user)
          expect(response).to have_http_status(:not_found)
        end
      end
    end

    patch('update item category') do
      tags 'Item Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      parameter name: :item_category, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Updated Category Name' },
          active: { type: :boolean, example: false }
        }
      }

      let(:item_category_params) { { item_category: { name: 'Updated Name', active: false } } }

      response(200, 'successful') do
        let(:user) { create(:user, :org_owner) } # Admin can update
        before { patch v1_item_category_path(id: id), params: item_category_params, headers: auth_headers(user) }

        it 'updates the item category and returns 200' do
          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['name']).to eq('Updated Name')
          expect(item_category_record.reload.name).to eq('Updated Name')
        end
      end

      response(401, 'unauthorized') do
        it 'returns a 401 response' do
          patch v1_item_category_path(id: id), params: item_category_params, headers: {} # Pass empty headers
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response(403, 'forbidden') do
        let(:user) { create(:user, :member) } # Regular user forbidden
        it 'returns a 403 response' do
          patch v1_item_category_path(id: id), params: item_category_params, headers: auth_headers(user)
          expect(response).to have_http_status(:forbidden)
        end
      end

      response(404, 'not found') do
        let(:id) { 0 } # Non-existent ID
        let(:user) { create(:user, :org_owner) }
        it 'returns a 404 response' do
          patch v1_item_category_path(id: id), params: item_category_params, headers: auth_headers(user)
          expect(response).to have_http_status(:not_found)
        end
      end

      response(422, 'unprocessable entity') do
        let(:user) { create(:user, :org_owner) }
        let(:item_category_params) { { item_category: { name: '' } } } # Invalid name
        it 'returns a 422 response' do
          patch v1_item_category_path(id: id), params: item_category_params, headers: auth_headers(user)
          expect(response).to have_http_status(:unprocessable_content)
        end
      end
    end

    delete('delete item category') do
      tags 'Item Categories'
      produces 'application/json'
      security [bearerAuth: []]

      response(204, 'no content') do
        let(:user) { create(:user, :org_owner) } # Admin can delete
        before { delete v1_item_category_path(id: id), headers: auth_headers(user) }

        it 'deletes the item category and returns 204' do
          expect(response).to have_http_status(:no_content)
          expect(ItemCategory.find_by(id: item_category_record.id)).to be_nil
        end
      end

      response(401, 'unauthorized') do
        it 'returns a 401 response' do
          delete v1_item_category_path(id: id), headers: {} # Pass empty headers
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response(403, 'forbidden') do
        let(:user) { create(:user, :member) } # Regular user forbidden
        it 'returns a 403 response' do
          delete v1_item_category_path(id: id), headers: auth_headers(user)
          expect(response).to have_http_status(:forbidden)
        end
      end

      response(404, 'not found') do
        let(:id) { 0 } # Non-existent ID
        let(:user) { create(:user, :org_owner) }
        it 'returns a 404 response' do
          delete v1_item_category_path(id: id), headers: auth_headers(user)
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
