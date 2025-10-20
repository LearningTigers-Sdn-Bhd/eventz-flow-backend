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
      message: { type: :string, example: 'Only an organization owner or manager can manage event staff.' }
    },
    required: %w[error message]
  }.freeze

  # ============================================================
  # Setup
  # ============================================================
  let(:event)        { create(:event) }
  let(:manager)      { create(:user, role: 'manager') }
  let(:member_user)  { create(:user, role: 'member') }

  # use the real encoder to generate valid tokens
  let(:auth_header_manager) { "Bearer #{JsonWebToken.encode(user_id: manager.id)}" }
  let(:auth_header_member)  { "Bearer #{JsonWebToken.encode(user_id: member_user.id)}" }

  let(:common_headers) { |auth| { 'Authorization' => auth, 'Content-Type' => 'application/json' } }

  # ============================================================
  # POST /v1/events/{event_id}/staff
  # ============================================================
  path '/v1/events/{event_id}/staff' do
    parameter name: :event_id, in: :path, type: :integer, required: true, description: 'ID of the parent event'

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
  let(:Authorization) { auth_header_manager }
  let(:body) { { staff_assignment: { user_id: member_user.id, role: 'event_admin' } } }

  response '201', 'Staff appointed successfully' do
    run_test!
  end

  response '403', 'Forbidden' do
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

      response '204', 'Staff removed successfully' do
        let(:Authorization) { auth_header_manager }
        run_test!
      end

      response '403', 'Forbidden' do
        let(:Authorization) { auth_header_member }
        schema EVENT_STAFF_ERROR_SCHEMA
        run_test!
      end

      response '404', 'Not Found' do
        let(:Authorization) { auth_header_manager }
        let(:user_id) { 99999 }
        schema EVENT_STAFF_ERROR_SCHEMA
        run_test!
      end
    end
  end
end
