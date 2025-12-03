require 'rails_helper'

RSpec.describe 'V1::PrintingServices', type: :request do
  let(:user) { create(:user) }
  let(:item_category) { create(:item_category) }

  before { sign_in(user) }

  path '/v1/printing_services' do
    get('list printing services') do
      tags 'Printing Services'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let!(:printing_service1) { create(:printing_service, item_category: item_category, user: user) }
        let!(:printing_service2) { create(:printing_service, item_category: item_category, user: user) }

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
          let!(:printing_service3) { create(:printing_service, item_category: item_category, user: user) }

          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data.count).to eq(1)
            expect(data.first['id']).to eq(printing_service3.id)
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
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['name']).to eq('New Printing Service')
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
          run_test!
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:service_creator) { create(:user) }
          run_test!
        end

        context 'as the exhibition contractor who created the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { user }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { create(:user) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:service_creator) { create(:user) }
          run_test!
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
          run_test! do |response|
            data = JSON.parse(response.body)
            expect(data['name']).to eq('Updated Printing Service Name')
          end
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:service_creator) { create(:user) }
          run_test!
        end

        context 'as the exhibition contractor who created the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { user }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { create(:user) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:service_creator) { create(:user) }
          run_test!
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
          run_test!
        end

        context 'as an organizer' do
          let(:user) { create(:user, :organizer) }
          let(:service_creator) { create(:user) }
          run_test!
        end

        context 'as the exhibition contractor who created the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { user }
          run_test!
        end
      end

      response(403, 'forbidden') do
        context 'as an exhibition contractor who did not create the service' do
          let(:user) { create(:user, :exhibition_contractor) }
          let(:service_creator) { create(:user) }
          run_test!
        end

        context 'as a regular user' do
          let(:user) { create(:user, :member) }
          let(:service_creator) { create(:user) }
          run_test!
        end
      end
    end
  end
end
