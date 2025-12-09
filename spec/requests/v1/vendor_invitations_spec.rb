# spec/requests/v1/vendor_invitations_spec.rb
require 'swagger_helper'

RSpec.describe 'Vendor Invitations', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Schemas
  # ============================================================
  INVITE_LINK_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean },
      message: { type: :string },
      data: {
        type: :object,
        properties: {
          invite_url: { type: :string },
          token: { type: :string },
          expires_at: { type: :string, format: :date_time },
          event: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string }
            }
          }
        }
      }
    }
  }.freeze

  VERIFY_TOKEN_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean },
      message: { type: :string },
      data: {
        type: :object,
        properties: {
          valid: { type: :boolean },
          expires_at: { type: :string, format: :date_time },
          organizer_id: { type: :integer },
          is_authenticated: { type: :boolean },
          is_assigned: { type: :boolean },
          event: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string },
              description: { type: :string, nullable: true },
              start_date: { type: :string, format: :date_time, nullable: true },
              end_date: { type: :string, format: :date_time, nullable: true }
            }
          }
        }
      }
    }
  }.freeze

  # ============================================================
  # Setup
  # ============================================================
  let(:organizer) { create(:user, :organizer) }
  let(:other_user) { create(:user, :member) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:event) { create(:event, title: 'Test Event 2024') }

  let(:auth_header_organizer) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" } }
  let(:auth_header_other) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(other_user)[:access_token]}" } }
  let(:auth_header_vendor) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(vendor_user)[:access_token]}" } }

  before do
    create(:event_assignment, event: event, user: organizer, role: 'event_admin')
  end

  # ============================================================
  # POST /v1/events/:event_id/vendor_invitations/generate_link
  # ============================================================
  describe 'POST /v1/events/:event_id/vendor_invitations/generate_link' do
    let(:path) { "/v1/events/#{event.id}/vendor_invitations/generate_link" }

    context 'when authenticated as event admin' do
      it 'generates an invitation link successfully' do
        post path, headers: auth_header_organizer

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['success']).to be true
        expect(data['message']).to eq('Invitation link generated successfully')
        expect(data['data']['invite_url']).to be_present
        expect(data['data']['token']).to be_present
        expect(data['data']['expires_at']).to be_present
        expect(data['data']['event']['id']).to eq(event.id)
        expect(data['data']['event']['title']).to eq('Test Event 2024')
      end

      it 'includes the token in the invite_url' do
        post path, headers: auth_header_organizer

        data = JSON.parse(response.body)
        expect(data['data']['invite_url']).to include(data['data']['token'])
      end
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        post path

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated but not authorized' do
      it 'returns forbidden' do
        post path, headers: auth_header_other

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when event does not exist' do
      it 'returns not found' do
        post "/v1/events/99999/vendor_invitations/generate_link", headers: auth_header_organizer

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  # ============================================================
  # GET /v1/events/:event_id/vendor_invitations/verify
  # ============================================================
  describe 'GET /v1/events/:event_id/vendor_invitations/verify' do
    let(:path) { "/v1/events/#{event.id}/vendor_invitations/verify" }
    let(:valid_payload) { { event_id: event.id, organizer_id: organizer.id, exp: 7.days.from_now.to_i } }
    let(:valid_token) { Rails.application.message_verifier(:vendor_invite).generate(valid_payload) }

    context 'with a valid token' do
      it 'verifies the token successfully' do
        get path, params: { token: valid_token }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['success']).to be true
        expect(data['message']).to eq('Token is valid')
        expect(data['data']['valid']).to be true
        expect(data['data']['organizer_id']).to eq(organizer.id)
        expect(data['data']['is_authenticated']).to be false
        expect(data['data']['is_assigned']).to be false
        expect(data['data']['event']['id']).to eq(event.id)
        expect(data['data']['event']['title']).to eq('Test Event 2024')
      end
    end

    context 'with an authenticated vendor' do
      it 'returns is_authenticated as true' do
        get path, params: { token: valid_token }, headers: auth_header_vendor

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['data']['is_authenticated']).to be true
        expect(data['data']['is_assigned']).to be false
      end

      context 'when vendor is already assigned to the event' do
        before do
          create(:merchant, event: event, vendor: vendor_user)
        end

        it 'returns is_assigned as true' do
          get path, params: { token: valid_token }, headers: auth_header_vendor

          expect(response).to have_http_status(:ok)
          data = JSON.parse(response.body)
          expect(data['data']['is_authenticated']).to be true
          expect(data['data']['is_assigned']).to be true
        end
      end
    end

    context 'when token is missing' do
      it 'returns unprocessable content' do
        get path

        expect(response).to have_http_status(:unprocessable_content)
        data = JSON.parse(response.body)
        expect(data['message']).to eq('Token is required')
      end

      it 'returns unprocessable content with empty token' do
        get path, params: { token: '' }

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when token is invalid' do
      it 'returns unauthorized' do
        get path, params: { token: 'invalid_token_here' }

        expect(response).to have_http_status(:unauthorized)
        data = JSON.parse(response.body)
        expect(data['message']).to eq('Invalid invitation link')
      end
    end

    context 'when token is expired' do
      let(:expired_payload) { { event_id: event.id, organizer_id: organizer.id, exp: 1.day.ago.to_i } }
      let(:expired_token) { Rails.application.message_verifier(:vendor_invite).generate(expired_payload) }

      it 'returns gone status' do
        get path, params: { token: expired_token }

        expect(response).to have_http_status(:gone)
        data = JSON.parse(response.body)
        expect(data['message']).to eq('Invitation link expired')
      end
    end

    context 'when event no longer exists' do
      let(:deleted_event_payload) { { event_id: 99999, organizer_id: organizer.id, exp: 7.days.from_now.to_i } }
      let(:deleted_event_token) { Rails.application.message_verifier(:vendor_invite).generate(deleted_event_payload) }

      it 'returns not found' do
        get "/v1/events/99999/vendor_invitations/verify", params: { token: deleted_event_token }

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when event_id in path does not exist' do
      it 'returns not found' do
        get "/v1/events/99999/vendor_invitations/verify", params: { token: valid_token }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
