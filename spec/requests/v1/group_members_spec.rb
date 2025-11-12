# spec/requests/v1/group_members_spec.rb
require 'swagger_helper'

GROUP_MEMBER_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer },
    user_id: { type: :integer },
    user: {
      type: :object,
      properties: {
        id: { type: :integer },
        email: { type: :string },
        full_name: { type: :string },
        role: { type: :string }
      }
    },
    has_manager_access: { type: :boolean },
    created_at: { type: :string, format: :date_time },
    updated_at: { type: :string, format: :date_time }
  }
}.freeze

RSpec.describe 'V1::GroupMembers', type: :request do
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:member_user) { create(:member_user) }
  let(:another_manager) { create(:manager_user) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:manager_token) { JwtService.generate_tokens(manager_user)[:access_token] }

  let!(:group) do
    group = create(:group, name: 'Test Group')
    create(:group_member, group: group, user: manager_user, has_manager_access: true)
    group
  end

  # =========================================================================
  # GET /v1/groups/:group_id/members
  # =========================================================================

  path '/v1/groups/{group_id}/members' do
    parameter name: :group_id, in: :path, type: :integer, description: 'Group ID'

    get 'Lists group members' do
      tags 'Group Members'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      response '200', 'Members retrieved' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:group_id) { group.id }
        schema type: :array, items: GROUP_MEMBER_SCHEMA
        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(1)
        end
      end

      response '403', 'Forbidden' do
        let(:Authorization) { "Bearer #{JwtService.generate_tokens(member_user)[:access_token]}" }
        let(:group_id) { group.id }
        run_test!
      end
    end

    # =========================================================================
    # POST /v1/groups/:group_id/members
    # =========================================================================

    post 'Adds a member to a group' do
      tags 'Group Members'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :group_id, in: :path, type: :integer, description: 'Group ID'
      parameter name: :group_member, in: :body, schema: {
        type: :object,
        properties: {
          user_id: { type: :integer },
          has_manager_access: { type: :boolean }
        },
        required: ['user_id']
      }

      response '201', 'Member added' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:group_id) { group.id }
        let(:group_member) { { group_member: { user_id: member_user.id, has_manager_access: false } } }
        schema GROUP_MEMBER_SCHEMA
        run_test!
      end

      response '201', 'Member added by group manager' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:group_id) { group.id }
        let(:group_member) { { group_member: { user_id: another_manager.id, has_manager_access: true } } }
        schema GROUP_MEMBER_SCHEMA
        run_test!
      end

      response '403', 'Forbidden' do
        let(:Authorization) { "Bearer #{JwtService.generate_tokens(member_user)[:access_token]}" }
        let(:group_id) { group.id }
        let(:group_member) { { group_member: { user_id: another_manager.id } } }
        run_test!
      end
    end
  end

  # =========================================================================
  # PATCH /v1/groups/:group_id/members/:id
  # =========================================================================

  path '/v1/groups/{group_id}/members/{id}' do
    parameter name: :group_id, in: :path, type: :integer, description: 'Group ID'
    parameter name: :id, in: :path, type: :integer, description: 'Group Member ID'

    patch 'Updates a group member' do
      tags 'Group Members'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :group_member, in: :body, schema: {
        type: :object,
        properties: {
          has_manager_access: { type: :boolean }
        }
      }

      response '200', 'Member updated' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:group_id) { group.id }
        let!(:group_member) { create(:group_member, group: group, user: member_user, has_manager_access: false) }
        let(:id) { group_member.id }
        let(:group_member_params) { { group_member: { has_manager_access: true } } }
        schema GROUP_MEMBER_SCHEMA
        run_test!
      end
    end

    # =========================================================================
    # DELETE /v1/groups/:group_id/members/:id
    # =========================================================================

    delete 'Removes a member from a group' do
      tags 'Group Members'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      response '204', 'Member removed' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:group_id) { group.id }
        let!(:group_member) { create(:group_member, group: group, user: member_user) }
        let(:id) { group_member.id }
        run_test!
      end
    end
  end
end
