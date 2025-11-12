# spec/requests/v1/event_vendor_profiles_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::EventVendorProfiles', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # --- Setup Users & Tokens ---
  let(:vendor_user) { create(:user, role: :vendor) }
  let(:other_vendor) { create(:user, role: :vendor) }
  let(:admin_user) { create(:user, role: :manager) }

  let(:vendor_token) { JwtService.generate_tokens(vendor_user)[:access_token] }
  let(:other_vendor_token) { JwtService.generate_tokens(other_vendor)[:access_token] }
  let(:admin_token) { JwtService.generate_tokens(admin_user)[:access_token] }

  # --- Setup Event and Vendor ---
  let(:event) { create(:event) }
  let!(:event_admin) { create(:event_assignment, event: event, user: admin_user, role: 'event_admin') }
  let!(:event_vendor) { create(:event_vendor, event: event, vendor: vendor_user, redirect_url: 'https://example.com/vendor') }

  path '/v1/events/{event_id}/vendors/{id}/profile' do
    parameter name: 'event_id', in: :path, type: :integer, description: 'Event ID'
    parameter name: 'id', in: :path, type: :integer, description: 'Event Vendor ID'
    parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

    get 'Get event vendor profile' do
      tags 'Event Vendor Profiles'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      response '200', 'Profile retrieved successfully' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 event_id: { type: :integer },
                 vendor_id: { type: :integer },
                 redirect_url: { type: :string },
                 poster_url: { type: :string, nullable: true },
                 created_at: { type: :string, format: :date_time },
                 updated_at: { type: :string, format: :date_time }
               }

        let(:event_id) { event.id }
        let(:id) { event_vendor.id }
        let(:Authorization) { "Bearer #{vendor_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['id']).to eq(event_vendor.id)
          expect(data['redirect_url']).to eq('https://example.com/vendor')
        end
      end

      response '403', 'Forbidden - not the vendor' do
        let(:event_id) { event.id }
        let(:id) { event_vendor.id }
        let(:Authorization) { "Bearer #{other_vendor_token}" }

        run_test!
      end
    end

    patch 'Update event vendor profile' do
      tags 'Event Vendor Profiles'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          profile: {
            type: :object,
            properties: {
              redirect_url: { type: :string },
              poster_url: { type: :string }
            }
          }
        }
      }

      response '200', 'Profile updated successfully' do
        let(:event_id) { event.id }
        let(:id) { event_vendor.id }
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:body) do
          {
            profile: {
              redirect_url: 'https://updated.example.com',
              poster_url: 'https://example.com/poster.jpg'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['redirect_url']).to eq('https://updated.example.com')
          expect(data['poster_url']).to eq('https://example.com/poster.jpg')
        end
      end

      response '403', 'Forbidden - not the vendor' do
        let(:event_id) { event.id }
        let(:id) { event_vendor.id }
        let(:Authorization) { "Bearer #{other_vendor_token}" }
        let(:body) { { profile: { redirect_url: 'https://updated.example.com' } } }

        run_test!
      end
    end
  end
end
