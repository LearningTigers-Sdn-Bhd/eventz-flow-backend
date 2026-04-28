require 'rails_helper'

RSpec.describe 'V1::RegistrationFormRsvpSettings', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:event) { create(:event) }
  let(:registration_form) { create(:registration_form, event: event) }
  let(:headers) { auth_headers(organizer) }

  before do
    create(:event_assignment, event: event, user: organizer, role: :event_admin)
  end

  describe 'GET /v1/events/:event_id/registration_forms/:registration_form_id/rsvp_setting' do
    it 'returns defaults when setting does not exist yet' do
      get "/v1/events/#{event.id}/registration_forms/#{registration_form.id}/rsvp_setting", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['registration_form_id']).to eq(registration_form.id)
      expect(json['enabled']).to eq(false)
      expect(json['rsvp_required']).to eq(false)
      expect(json['review_sla_hours']).to eq(48)
      expect(json['rsvp_expires_in_hours']).to be_nil
    end
  end

  describe 'PUT /v1/events/:event_id/registration_forms/:registration_form_id/rsvp_setting' do
    it 'updates RSVP settings for the registration form' do
      put "/v1/events/#{event.id}/registration_forms/#{registration_form.id}/rsvp_setting",
          headers: headers,
          params: {
            registration_form_rsvp_setting: {
              enabled: true,
              rsvp_required: true,
              rsvp_expires_in_hours: 72,
              review_sla_hours: 24,
              notify_by_date: '2026-05-15T18:00:00Z'
            }
          },
          as: :json

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['enabled']).to eq(true)
      expect(json['rsvp_required']).to eq(true)
      expect(json['rsvp_expires_in_hours']).to eq(72)
      expect(json['review_sla_hours']).to eq(24)
      expect(Time.zone.parse(json['notify_by_date']).utc.iso8601).to eq('2026-05-15T18:00:00Z')
    end
  end
end
