require 'rails_helper'

RSpec.describe 'V1::RentableItems', type: :request do
  let(:user) { create(:user) }
  let(:item_category) { create(:item_category) }

  before { sign_in(user) }

  path '/v1/rentable_items' do
    get('list rentable items') do
      tags 'Rentable Items'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let!(:rentable_item1) { create(:rentable_item, item_category: item_category, user: user) }
        let!(:rentable_item2) { create(:rentable_item, item_category: item_category, user: user) }

        context 'as an admin' do
          let(:user) { create(:user, :org_owner) }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data.count).to eq(2)
          end
        end

        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          let!(:rentable_item3) { create(:rentable_item, item_category: item_category, user: user) }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data.count).to eq(1)
            expect(data.first['id']).to eq(rentable_item3.id)
          end
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data).to be_empty
          end
        end
      end

      response(401, 'unauthorized') do
        let(:Authorization) { nil }
        run_test!
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
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['name']).to eq('New Rentable Item')
            expect(data['user_id']).to eq(user.id)
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          run_test!
        end

        context 'as an exhibition contractor' do
          let(:user) { create(:user, :exhibition_contractor) }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          run_test!
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
          run_test!
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:item_creator) { create(:user) }
          run_test!
        end

        context 'as the exhibition contractor who created the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { user }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { create(:user) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:item_creator) { create(:user) }
          run_test!
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
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['name']).to eq('Updated Name')
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:item_creator) { create(:user) }
          run_test!
        end

        context 'as the exhibition contractor who created the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { user }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { create(:user) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:item_creator) { create(:user) }
          run_test!
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
          run_test!
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:item_creator) { create(:user) }
          run_test!
        end

        context 'as the exhibition contractor who created the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { user }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the item' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:item_creator) { create(:user) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:item_creator) { create(:user) }
          run_test!
        end
      end
    end
  end
end
