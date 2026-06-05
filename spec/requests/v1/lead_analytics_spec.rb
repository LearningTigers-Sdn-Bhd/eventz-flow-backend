# lead_analytics_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::LeadAnalytics', type: :request do
  # --- Setup Users & Tokens ---
  let(:vendor_user) { create(:user, role: :vendor) }
  let(:vendor_token) { JwtService.generate_tokens(vendor_user)[:access_token] }

  # --- Setup Event ---
  let!(:event) do
    create(:event, title: 'Test Event', payment_status: :paid, use_ticket: false, use_event_leads: true)
  end

  # --- Setup Event Vendor ---
  let!(:event_vendor) do
    create(:event_vendor, event: event, vendor: vendor_user, redirect_url: 'https://example.com')
  end

  # --- Setup Visitors and Leads ---
  let!(:visitor1) { create(:visitor, event: event, full_name: 'Visitor 1', phone: '+1234567890') }
  let!(:visitor2) { create(:visitor, event: event, full_name: 'Visitor 2', phone: '+1234567891') }
  let!(:lead1) { create(:event_lead, leadable: visitor1, event_vendor: event_vendor) }
  let!(:lead2) { create(:event_lead, leadable: visitor2, event_vendor: event_vendor) }

  path '/v1/events/{event_id}/vendors/{id}/lead_count' do
    parameter name: 'event_id', in: :path, type: :string, description: 'Event ID'
    parameter name: 'id', in: :path, type: :string, description: 'Event Vendor ID'

    get 'Gets lead count for a vendor' do
      tags 'Lead Analytics'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      response '200', 'Lead count retrieved' do
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:event_id) { event.id }
        let(:id) { event_vendor.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['lead_count']).to eq(2)
          expect(data['event_id']).to eq(event.id)
          expect(data['vendor_id']).to eq(vendor_user.id)
        end
      end

      response '404', 'Event not found' do
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:event_id) { 99999 }
        let(:id) { event_vendor.id }

        run_test!
      end

      response '404', 'Event vendor not found' do
        let(:Authorization) { "Bearer #{vendor_token}" }
        let(:event_id) { event.id }
        let(:id) { 99999 }

        run_test!
      end
    end
  end
end
