# spec/requests/v1/vendor_profiles_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::VendorProfiles', type: :request do
  # --- Setup Users & Tokens ---
  let(:vendor_user) { create(:user, role: :vendor) }
  let(:other_vendor) { create(:user, role: :vendor) }
  let(:admin_user) { create(:organizer_user) }

  let(:vendor_token) { JwtService.generate_tokens(vendor_user)[:access_token] }
  let(:other_vendor_token) { JwtService.generate_tokens(other_vendor)[:access_token] }
  let(:admin_token) { JwtService.generate_tokens(admin_user)[:access_token] }

  # --- Setup Group and Vendor Affiliation ---
  let(:group) { create(:group) }
  let!(:group_affiliate) do
    create(:group_affiliate, group: group, vendor: vendor_user)
  end
  let!(:vendor_profile) do
    create(:vendor_profile, group: group, vendor: vendor_user)
  end

  path '/v1/groups/{group_id}/vendors/{vendor_id}/profile' do
    parameter name: 'group_id', in: :path, type: :integer, description: 'Group ID'
    parameter name: 'vendor_id', in: :path, type: :integer, description: 'Vendor ID'
    parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

    patch 'Update vendor profile' do
      tags 'Vendor Profiles'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :vendor_profile, in: :body, schema: {
        type: :object,
        properties: {
          vendor_profile: {
            type: :object,
            properties: {
              image_path: { type: :string, nullable: true, example: '/images/vendor.jpg' },
              vendor_name: { type: :string, example: 'My Vendor Name' },
              vendor_description: { type: :string, nullable: true, example: 'Vendor description' }
            }
          }
        },
        required: ['vendor_profile']
      }

      response '200', 'Vendor profile updated successfully' do
        schema type: :object,
               properties: {
                 id: { type: :integer },
                 group_id: { type: :integer },
                 vendor_id: { type: :integer },
                 image_path: { type: :string, nullable: true },
                 vendor_name: { type: :string },
                 vendor_description: { type: :string, nullable: true },
                 created_at: { type: :string, format: :date_time },
                 updated_at: { type: :string, format: :date_time }
               }

        let(:group_id) { group.id }
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:vendor_profile) do
          {
            vendor_profile: {
              vendor_name: 'Updated Vendor Name',
              vendor_description: 'Updated description'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['vendor_name']).to eq('Updated Vendor Name')
          expect(data['vendor_description']).to eq('Updated description')
        end
      end

      response '403', 'Forbidden - not a vendor for this group' do
        let(:group_id) { group.id }
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{other_vendor_token}" }
        let(:vendor_profile) { { vendor_profile: { vendor_name: 'Test' } } }

        run_test!
      end

      response '404', 'Group not found' do
        let(:group_id) { 99999 }
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:vendor_profile) { { vendor_profile: { vendor_name: 'Test' } } }

        run_test!
      end

      response '200', 'Vendor profile updated with partial data' do
        let(:group_id) { group.id }
        let(:vendor_id) { vendor_user.id }
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:vendor_profile) { { vendor_profile: { vendor_name: 'Updated Name' } } }

        run_test!
      end
    end
  end
end
