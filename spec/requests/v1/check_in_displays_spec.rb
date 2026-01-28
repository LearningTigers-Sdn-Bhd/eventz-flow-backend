# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::CheckInDisplays', type: :request do
  # --- Setup Users ---
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }
  let(:event_admin) { create(:user, :member) }
  let(:event_team_member) { create(:user, :member) }
  let(:unassigned_member) { create(:user, :member) }

  # --- Setup Tokens ---
  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer)[:access_token] }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }
  let(:event_team_member_token) { JwtService.generate_tokens(event_team_member)[:access_token] }
  let(:unassigned_member_token) { JwtService.generate_tokens(unassigned_member)[:access_token] }

  # --- Setup Event ---
  let!(:event) do
    event = create(:event)
    create(:event_assignment, event: event, user: event_admin, role: :event_admin)
    create(:event_assignment, event: event, user: event_team_member, role: :event_team_member)
    event
  end

  # --- Endpoints ---
  let(:show_endpoint) { "/v1/events/#{event.id}/check_in_display" }
  let(:update_endpoint) { "/v1/events/#{event.id}/check_in_display" }

  describe 'GET /v1/events/:event_id/check_in_display' do
    context 'when no check_in_display exists' do
      it 'returns default settings for org_owner' do
        get show_endpoint, headers: auth_headers(org_owner_token)

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['font_family']).to eq('Inter')
        expect(data['font_size']).to eq(72)
        expect(data['animation_type']).to eq('fade_in')
        expect(data['background_image_url']).to be_nil
      end

      it 'returns default settings for event_admin' do
        get show_endpoint, headers: auth_headers(event_admin_token)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['font_family']).to eq('Inter')
      end

      it 'returns default settings for event_team_member' do
        get show_endpoint, headers: auth_headers(event_team_member_token)

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when check_in_display exists' do
      let!(:display) { create(:check_in_display, event: event, font_family: 'Roboto', font_size: 96) }

      it 'returns saved settings' do
        get show_endpoint, headers: auth_headers(org_owner_token)

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['id']).to eq(display.id)
        expect(data['font_family']).to eq('Roboto')
        expect(data['font_size']).to eq(96)
      end
    end

    context 'authorization' do
      it 'returns 403 for unassigned member' do
        get show_endpoint, headers: auth_headers(unassigned_member_token)

        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 401 without token' do
        get show_endpoint

        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 404 for non-existent event' do
        get '/v1/events/99999/check_in_display', headers: auth_headers(org_owner_token)

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'PUT /v1/events/:event_id/check_in_display' do
    let(:valid_params) do
      {
        check_in_display: {
          font_family: 'Montserrat',
          font_size: 64,
          animation_type: 'slide_up'
        }
      }
    end

    context 'when no check_in_display exists (upsert)' do
      it 'creates and returns new settings for org_owner' do
        expect {
          put update_endpoint, params: valid_params, headers: auth_headers(org_owner_token)
        }.to change(CheckInDisplay, :count).by(1)

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['font_family']).to eq('Montserrat')
        expect(data['font_size']).to eq(64)
        expect(data['animation_type']).to eq('slide_up')
      end

      it 'creates settings for event_admin' do
        put update_endpoint, params: valid_params, headers: auth_headers(event_admin_token)

        expect(response).to have_http_status(:ok)
        expect(json_response['data']['font_family']).to eq('Montserrat')
      end
    end

    context 'when check_in_display exists' do
      let!(:display) { create(:check_in_display, event: event) }

      it 'updates existing settings' do
        expect {
          put update_endpoint, params: valid_params, headers: auth_headers(org_owner_token)
        }.not_to change(CheckInDisplay, :count)

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['font_family']).to eq('Montserrat')

        display.reload
        expect(display.font_family).to eq('Montserrat')
      end

      it 'allows partial update' do
        put update_endpoint, params: { check_in_display: { font_size: 48 } }, headers: auth_headers(org_owner_token)

        expect(response).to have_http_status(:ok)
        display.reload
        expect(display.font_size).to eq(48)
        expect(display.font_family).to eq('Inter') # unchanged
      end
    end

    context 'validation errors' do
      it 'returns error for invalid font_size' do
        put update_endpoint, params: { check_in_display: { font_size: 0 } }, headers: auth_headers(org_owner_token)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_response['errors']).to include('Font size must be greater than 0')
      end

      it 'returns error for negative font_size' do
        put update_endpoint, params: { check_in_display: { font_size: -10 } }, headers: auth_headers(org_owner_token)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'authorization' do
      it 'returns 403 for unassigned member' do
        put update_endpoint, params: valid_params, headers: auth_headers(unassigned_member_token)

        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 401 without token' do
        put update_endpoint, params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # --- Helper Methods ---
  def auth_headers(token)
    { 'Authorization' => "Bearer #{token}" }
  end

  def json_response
    JSON.parse(response.body)
  end
end
