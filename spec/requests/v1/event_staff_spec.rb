# spec/requests/v1/event_staff_spec.rb
require 'swagger_helper'

RSpec.describe 'Event Staff Management', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  EVENT_STAFF_ERROR_SCHEMA = {
    type: :object,
    properties: {
      error: { type: :string, example: 'Forbidden' },
      message: { type: :string, example: 'Only an organization owner or organizer can manage event staff.' }
    },
    required: %w[error message]
  }.freeze

  # ============================================================
  # Setup
  # ============================================================
  let(:event)        { create(:event) }
  let(:org_owner)    { create(:user, :org_owner) }
  let(:organizer)      { create(:user, :organizer) }
  let(:member_user)  { create(:user, :member) }
  let(:bm_admin_user) { create(:user, :member) }

  # use the real encoder to generate valid tokens
  let(:auth_header_org_owner) { "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" }
  let(:auth_header_organizer) { "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" }
  let(:auth_header_member)  { "Bearer #{JwtService.generate_tokens(member_user)[:access_token]}" }
  let(:auth_header_bm_admin) { "Bearer #{JwtService.generate_tokens(bm_admin_user)[:access_token]}" }

  let(:common_headers) { |auth| { 'Authorization' => auth, 'Content-Type' => 'application/json' } }

  # ============================================================
  # GET /v1/events/{event_id}/staff
  # ============================================================
  path '/v1/events/{event_id}/staff' do
    parameter name: :event_id, in: :path, type: :integer, required: true, description: 'ID of the parent event'

    get 'Lists all staff assigned to an event' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
      parameter name: :event_id, in: :path, type: :integer, required: true, description: 'Event ID'

      let(:event_id) { event.id }
      let(:Authorization) { auth_header_org_owner }

      before do
        # Create some staff assignments for the event
        create(:event_assignment, event: event, user: member_user, role: 'event_team_member')
        create(:event_assignment, event: event, user: organizer, role: 'event_admin')
        create(:event_assignment, event: event, user: bm_admin_user, role: 'business_matching_admin')
      end

      response '200', 'Returns list of staff assigned to the event (Org Owner)' do
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              event_id: { type: :integer },
              user_id: { type: :integer },
              role: { type: :string },
              user: {
                type: :object,
                properties: {
                  id: { type: :integer },
                  email: { type: :string },
                  full_name: { type: :string, nullable: true },
                  phone: { type: :string, nullable: true },
                  role: { type: :string },
                  status: { type: :string }
                }
              }
            },
            required: %w[id event_id user_id role]
          }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to be_an(Array)
          expect(data.length).to eq(3)
          expect(data.first).to have_key('user')
        end
      end

      response '200', 'Organizer can view staff if they are event staff' do
        let(:Authorization) { auth_header_organizer }

        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              event_id: { type: :integer },
              user_id: { type: :integer },
              role: { type: :string }
            }
          }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to be_an(Array)
          # Organizer is admin, so they can view
          expect(data.length).to eq(3)
        end
      end

      response '200', 'Business Matching admin can view staff for their assigned event' do
        let(:Authorization) { auth_header_bm_admin }

        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              event_id: { type: :integer },
              user_id: { type: :integer },
              role: { type: :string }
            }
          }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data).to be_an(Array)
          expect(data.length).to eq(3)
        end
      end

      response '403', 'Forbidden for member users who are not event staff' do
        let(:Authorization) { auth_header_member }
        let(:other_event) { create(:event) }
        let(:event_id) { other_event.id }

        schema EVENT_STAFF_ERROR_SCHEMA
        run_test!
      end

      response '404', 'Event not found' do
        let(:Authorization) { auth_header_org_owner }
        let(:event_id) { 99999 }
        schema type: :object,
          properties: {
            error: { type: :string },
            message: { type: :string }
          }
        run_test!
      end
    end

    post 'Appoints a user to an event role' do
  tags 'Events'
  security [{ BearerAuth: [] }]
  consumes 'application/json'
  produces 'application/json'

  parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
  parameter name: :event_id, in: :path, type: :integer, required: true, description: 'Event ID'
  parameter name: :body, in: :body, required: true, schema: {
    type: :object,
    properties: {
      staff_assignment: {
        type: :object,
        properties: {
          user_id: { type: :integer },
          role: { type: :string }
        },
        required: %w[user_id role]
      }
    },
    required: ['staff_assignment']
  }

  let(:event_id) { event.id }
  let(:Authorization) { auth_header_org_owner }
  let(:body) { { staff_assignment: { user_id: member_user.id, role: 'event_admin' } } }

  response '201', 'Staff appointed successfully (Org Owner)' do
    run_test!
  end

  response '201', 'Staff appointed successfully (Organizer)' do
    let(:Authorization) { auth_header_organizer }
    run_test!
  end

  response '201', 'Business matching admin appointed successfully' do
    let(:body) { { staff_assignment: { user_id: member_user.id, role: 'business_matching_admin' } } }
    run_test! do |response|
      data = JSON.parse(response.body)
      expect(data['role']).to eq('business_matching_admin')
    end
  end

  response '403', 'Forbidden for member' do
    let(:Authorization) { auth_header_member }
    schema EVENT_STAFF_ERROR_SCHEMA
    run_test!
  end
end

  end

  # ============================================================
  # DELETE /v1/events/{event_id}/staff/{user_id}
  # ============================================================
  path '/v1/events/{event_id}/staff/{user_id}' do
    parameter name: :event_id, in: :path, type: :integer, required: true, description: 'Event ID'
    parameter name: :user_id,  in: :path, type: :integer, required: true, description: 'User ID to remove'

    delete 'Removes a user from an event staff role' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'

      let(:event_id) { event.id }
      let(:user_id)  { member_user.id }

      before do
        create(:event_assignment, event: event, user: member_user, role: 'event_team_member')
      end

      response '204', 'Staff removed successfully (Org Owner)' do
        let(:Authorization) { auth_header_org_owner }
        run_test!
      end

      response '204', 'Staff removed successfully (Organizer)' do
        let(:Authorization) { auth_header_organizer }
        run_test!
      end

      response '403', 'Forbidden for member' do
        let(:Authorization) { auth_header_member }
        schema EVENT_STAFF_ERROR_SCHEMA
        run_test!
      end

      response '404', 'Not Found when user not assigned' do
        let(:Authorization) { auth_header_org_owner }
        let(:user_id) { 99999 }
        schema type: :object,
          properties: {
            error: { type: :string },
            message: { type: :string }
          }
        run_test!
      end
    end
  end
end
