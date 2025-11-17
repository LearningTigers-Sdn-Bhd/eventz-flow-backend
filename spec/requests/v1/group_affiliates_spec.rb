# spec/requests/v1/group_affiliates_spec.rb
require 'swagger_helper'

GROUP_AFFILIATE_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer },
    group_id: { type: :integer },
    vendor_id: { type: :integer },
    vendor: {
      type: :object,
      properties: {
        id: { type: :integer },
        email: { type: :string },
        full_name: { type: :string }
      }
    },
    created_at: { type: :string, format: :date_time },
    updated_at: { type: :string, format: :date_time }
  }
}.freeze

RSpec.describe 'V1::GroupAffiliates', type: :request do
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:organizer_user) }
  let(:vendor_user) { create(:vendor_user) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:manager_token) { JwtService.generate_tokens(manager_user)[:access_token] }

  let!(:group) { create(:group, name: 'Test Group') }

  # =========================================================================
  # POST /v1/groups/:group_id/affiliates
  # =========================================================================

  path '/v1/groups/{group_id}/affiliates' do
    parameter name: :group_id, in: :path, type: :integer, description: 'Group ID'

    post 'Assigns a vendor to a group (ORG_OWNER ONLY)' do
      tags 'Group Affiliates'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :group_affiliate, in: :body, schema: {
        type: :object,
        properties: {
          vendor_id: { type: :integer }
        },
        required: ['vendor_id']
      }

      response '201', 'Vendor assigned' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:group_id) { group.id }
        let(:group_affiliate) { { group_affiliate: { vendor_id: vendor_user.id } } }
        schema GROUP_AFFILIATE_SCHEMA
        run_test!
      end

      response '403', 'Forbidden (Not Org Owner)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:group_id) { group.id }
        let(:group_affiliate) { { group_affiliate: { vendor_id: vendor_user.id } } }
        run_test!
      end
    end

  end

  # =========================================================================
  # DELETE /v1/groups/:group_id/affiliates/:id
  # =========================================================================

  path '/v1/groups/{group_id}/affiliates/{id}' do
    parameter name: :group_id, in: :path, type: :integer, description: 'Group ID'
    parameter name: :id, in: :path, type: :integer, description: 'Affiliate ID'

    delete 'Removes vendor from a group (ORG_OWNER ONLY)' do
      tags 'Group Affiliates'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      response '204', 'Vendor removed' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:group_id) { group.id }
        let!(:affiliate) { create(:group_affiliate, group: group, vendor: vendor_user) }
        let(:id) { affiliate.id }
        run_test!
      end

      response '403', 'Forbidden (Not Org Owner)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:group_id) { group.id }
        let!(:affiliate) { create(:group_affiliate, group: group, vendor: vendor_user) }
        let(:id) { affiliate.id }
        run_test!
      end

      response '404', 'No affiliate found' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:group_id) { group.id }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end
