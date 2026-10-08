# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event Business Matching Email Settings', type: :request do
  let(:user) { create(:user, role: :org_owner) }
  let(:event) { create(:event, user: user) }
  let(:headers) { auth_headers(user) }

  describe 'PATCH /v1/events/:id' do
    it 'saves business matching email customization attributes' do
      patch "/v1/events/#{event.id}",
            params: {
              event: {
                event_email_setting_attributes: {
                  sender_name: 'Main Secretariat',
                  business_matching_sender_name: 'Secretariat B2B',
                  business_matching_host_label: 'Business Partner',
                  business_matching_host_invite_subject: 'Invitation to {{event_name}} ({{host_label}})',
                  business_matching_host_invite_message: 'Hello, please join us at {{event_name}}.'
                }
              }
            },
            headers: headers

      expect(response).to have_http_status(:ok)

      setting = event.reload.event_email_setting
      expect(setting).to be_present
      expect(setting.sender_name).to eq('Main Secretariat')
      expect(setting.business_matching_sender_name).to eq('Secretariat B2B')
      expect(setting.business_matching_host_label).to eq('Business Partner')
      expect(setting.business_matching_host_invite_subject).to eq('Invitation to {{event_name}} ({{host_label}})')
      expect(setting.business_matching_host_invite_message).to eq('Hello, please join us at {{event_name}}.')
    end
  end

  describe 'GET /v1/events/:id' do
    before do
      event.create_event_email_setting!(
        sender_name: 'Main Secretariat',
        business_matching_sender_name: 'Secretariat B2B',
        business_matching_host_label: 'Business Partner',
        business_matching_host_invite_subject: 'Invitation to {{event_name}} ({{host_label}})',
        business_matching_host_invite_message: 'Hello, please join us at {{event_name}}.'
      )
    end

    it 'returns business matching email fields in event_email_setting' do
      get "/v1/events/#{event.id}", headers: headers

      expect(response).to have_http_status(:ok)
      email_setting = json_response['event_email_setting']
      expect(email_setting).to be_present
      expect(email_setting['business_matching_sender_name']).to eq('Secretariat B2B')
      expect(email_setting['business_matching_host_label']).to eq('Business Partner')
      expect(email_setting['business_matching_host_invite_subject']).to eq('Invitation to {{event_name}} ({{host_label}})')
      expect(email_setting['business_matching_host_invite_message']).to eq('Hello, please join us at {{event_name}}.')
    end
  end
end
