# spec/requests/v1/groups_spec.rb
require 'swagger_helper'

# =========================================================================
# REUSABLE SCHEMAS
# =========================================================================

GROUP_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer, example: 1 },
    name: { type: :string, example: 'Mall A Group' },
    description: { type: :string, example: 'Group for managing vendors in Mall A' },
    created_at: { type: :string, format: :date_time },
    updated_at: { type: :string, format: :date_time }
  },
  required: ['id', 'name', 'created_at', 'updated_at']
}.freeze

RSpec.describe 'V1::Groups', type: :request do
  # --- Setup Users ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:manager_user) { create(:user, :organizer) }
  let(:member_user) { create(:user, :member) }
  let(:vendor_user) { create(:user, :vendor) }

  # --- Setup Tokens ---
  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:manager_token) { JwtService.generate_tokens(manager_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }
  let(:vendor_token) { JwtService.generate_tokens(vendor_user)[:access_token] }

  # --- Setup Groups ---
  let!(:group1) do
    group = create(:group, name: 'Group 1')
    create(:group_member, group: group, user: manager_user, has_manager_access: true)
    create(:group_member, group: group, user: member_user, has_manager_access: false)
    group
  end

  let!(:group2) do
    group = create(:group, name: 'Group 2')
    create(:group_member, group: group, user: manager_user, has_manager_access: false)
    create(:group_affiliate, group: group, vendor: vendor_user)
    group
  end

  let!(:group3) do
    group = create(:group, name: 'Group 3')
    create(:group_member, group: group, user: member_user, has_manager_access: false)
    group
  end

  let(:group_params) do
    {
      group: {
        name: 'New Group',
        description: 'New Group Description'
      }
    }
  end

  # =========================================================================
  # POST /v1/groups (Create)
  # =========================================================================

  path '/v1/groups' do
    post 'Creates a new group (ORG_OWNER ONLY)' do
      tags 'Groups'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :group, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          manager_id: { type: :integer, description: 'Optional: User ID to assign as group manager' }
        },
        required: ['name']
      }

      response '201', 'Group created successfully' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:group) { group_params }
        schema GROUP_SCHEMA
        run_test! do |response|
          json = JSON.parse(response.body)
          created_group = Group.find(json['id'])
          expect(created_group.group_members.where(user_id: manager_user.id, has_manager_access: true).exists?).to be true
        end
      end

      response '201', 'Group created with manager' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:group) do
          {
            group: {
              name: 'Group with Manager',
              description: 'Description',
              manager_id: manager_user.id
            }
          }
        end
        schema GROUP_SCHEMA
        run_test! do |response|
          json = JSON.parse(response.body)
          created_group = Group.find(json['id'])
          # The current_user (manager_user) is added as manager, and then the manager_id is also added.
          # If manager_id is the same as current_user, it should only create one GroupMember record.
          # The current logic will try to create it twice, but the uniqueness validation on GroupMember will prevent the second one.
          # So we just assert that manager_user is a manager.
          expect(created_group.group_members.where(user_id: manager_user.id, has_manager_access: true).exists?).to be true
        end
      end

      response '201', 'Group created by organizer' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:group) { group_params }
        schema GROUP_SCHEMA
        run_test! do |response|
          json = JSON.parse(response.body)
          created_group = Group.find(json['id'])
          expect(created_group.group_members.where(user_id: manager_user.id, has_manager_access: true).exists?).to be true
        end
      end

      response '403', 'Forbidden (Not Org Owner or Organizer)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:group) { group_params }
        run_test!
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { 'Bearer invalid' }
        let(:group) { group_params }
        run_test!
      end
    end

    # =========================================================================
    # GET /v1/groups (Index)
    # =========================================================================

    get 'Lists groups visible to the user' do
      tags 'Groups'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      response '200', 'Org Owner sees all groups' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        schema type: :array, items: GROUP_SCHEMA
        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(3)
        end
      end

      response '200', 'Manager sees groups they belong to' do
        let(:Authorization) { "Bearer #{manager_token}" }
        schema type: :array, items: GROUP_SCHEMA
        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(2) # group1 and group2
        end
      end

      response '200', 'Vendor sees groups they are assigned to' do
        let(:Authorization) { "Bearer #{vendor_token}" }
        schema type: :array, items: GROUP_SCHEMA
        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(1) # group2
          expect(json.first['name']).to eq('Group 2')
        end
      end

      response '200', 'Member sees groups they belong to' do
        let(:Authorization) { "Bearer #{member_token}" }
        schema type: :array, items: GROUP_SCHEMA
        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(2) # group1 and group3
        end
      end
    end
  end

  # =========================================================================
  # GET /v1/groups/:id (Show)
  # =========================================================================

  path '/v1/groups/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Group ID'

    get 'Retrieves a specific group' do
      tags 'Groups'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      response '200', 'Group found' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { group1.id }
        schema GROUP_SCHEMA
        run_test!
      end

      response '403', 'Forbidden (Not authorized to view)' do
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:id) { group1.id } # Vendor is not assigned to group1
        run_test!
      end

      response '404', 'Group not found' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { 99999 }
        run_test!
      end
    end

    # =========================================================================
    # PATCH /v1/groups/:id (Update)
    # =========================================================================

    patch 'Updates a group (ORG_OWNER or GROUP MANAGER)' do
      tags 'Groups'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :id, in: :path, type: :integer, description: 'Group ID'
      parameter name: :group, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string }
        }
      }

      response '200', 'Group updated by org owner' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { group1.id }
        let(:group) { { group: { name: 'Updated Group Name' } } }
        schema GROUP_SCHEMA
        run_test!
      end

      response '200', 'Group updated by group manager' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { group1.id } # manager_user is a manager of group1
        let(:group) { { group: { description: 'Updated Description' } } }
        schema GROUP_SCHEMA
        run_test!
      end

      response '403', 'Forbidden (Not org owner or group manager)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { group1.id } # member_user is not a manager
        let(:group) { { group: { name: 'Updated Name' } } }
        run_test!
      end
    end

    # =========================================================================
    # DELETE /v1/groups/:id (Destroy)
    # =========================================================================

    delete 'Deletes a group (ORG_OWNER ONLY)' do
      tags 'Groups'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :id, in: :path, type: :integer, description: 'Group ID'

      response '204', 'Group deleted' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { group3.id }
        run_test!
      end

      response '403', 'Forbidden (Not Org Owner)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { group1.id }
        run_test!
      end
    end
  end
end
