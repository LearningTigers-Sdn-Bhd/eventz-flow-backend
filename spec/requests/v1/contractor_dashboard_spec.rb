# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::ContractorDashboard', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:vendor_user) { create(:user, :vendor) }
  let(:contractor) { create(:user, :exhibition_contractor, with_profile: false) }
  let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor) }

  describe 'GET /v1/contractor/dashboard' do
    context 'as exhibition contractor with no assigned events' do
      it 'returns empty dashboard data' do
        get '/v1/contractor/dashboard', headers: auth_headers(contractor)

        expect(response).to have_http_status(:ok)
        expect(json_body['summary']).to include(
          'total_events' => 0,
          'active_events' => 0,
          'total_exhibitors' => 0,
          'total_received_amount' => 0.0,
          'pending_payments_count' => 0,
          'verified_payments_count' => 0
        )
        expect(json_body['events']).to eq([])
      end
    end

    context 'as exhibition contractor with assigned events' do
      let!(:event1) { create(:event, status: :published) }
      let!(:event2) { create(:event, status: :draft) }
      let!(:event_contractor1) do
        create(:event_exhibition_contractor,
               event: event1,
               exhibition_contractor_profile: contractor_profile)
      end
      let!(:event_contractor2) do
        create(:event_exhibition_contractor,
               event: event2,
               exhibition_contractor_profile: contractor_profile)
      end

      it 'returns dashboard with assigned events' do
        get '/v1/contractor/dashboard', headers: auth_headers(contractor)

        expect(response).to have_http_status(:ok)
        expect(json_body['summary']['total_events']).to eq(2)
        expect(json_body['summary']['active_events']).to eq(1)
        expect(json_body['events'].size).to eq(2)
      end

      it 'returns correct event data structure' do
        get '/v1/contractor/dashboard', headers: auth_headers(contractor)

        event_data = json_body['events'].find { |e| e['id'] == event1.id }
        expect(event_data).to include(
          'id' => event1.id,
          'title' => event1.title,
          'status' => 'published',
          'exhibitors_count' => 0,
          'total_received_amount' => 0.0,
          'pending_payments_count' => 0,
          'verified_payments_count' => 0
        )
        expect(event_data['start_date']).to be_present
        expect(event_data['end_date']).to be_present
      end
    end

    context 'as exhibition contractor with payments' do
      let!(:event) { create(:event, status: :published) }
      let!(:event_contractor) do
        create(:event_exhibition_contractor,
               event: event,
               exhibition_contractor_profile: contractor_profile)
      end
      let!(:exhibitor) { create(:exhibitor, event: event) }
      let!(:exhibitor_kit) { exhibitor.exhibitor_kit }

      let!(:verified_payment) do
        create(:exhibitor_kit_payment, :verified,
               exhibitor_kit: exhibitor_kit,
               payee: contractor,
               amount: 500.00)
      end
      let!(:pending_payment) do
        create(:exhibitor_kit_payment,
               exhibitor_kit: exhibitor_kit,
               payee: contractor,
               amount: 200.00,
               status: :pending)
      end
      let!(:submitted_payment) do
        create(:exhibitor_kit_payment, :submitted_manual_bank_in,
               exhibitor_kit: exhibitor_kit,
               payee: contractor,
               amount: 300.00)
      end

      it 'returns correct payment summary' do
        get '/v1/contractor/dashboard', headers: auth_headers(contractor)

        expect(response).to have_http_status(:ok)
        expect(json_body['summary']['total_received_amount']).to eq(500.0)
        expect(json_body['summary']['pending_payments_count']).to eq(2)
        expect(json_body['summary']['verified_payments_count']).to eq(1)
      end

      it 'returns correct per-event payment data' do
        get '/v1/contractor/dashboard', headers: auth_headers(contractor)

        event_data = json_body['events'].find { |e| e['id'] == event.id }
        expect(event_data['total_received_amount']).to eq(500.0)
        expect(event_data['pending_payments_count']).to eq(2)
        expect(event_data['verified_payments_count']).to eq(1)
        expect(event_data['exhibitors_count']).to eq(1)
      end
    end

    context 'as exhibition contractor with multiple exhibitors' do
      let!(:event) { create(:event, status: :published) }
      let!(:event_contractor) do
        create(:event_exhibition_contractor,
               event: event,
               exhibition_contractor_profile: contractor_profile)
      end
      let!(:exhibitor1) { create(:exhibitor, event: event) }
      let!(:exhibitor2) { create(:exhibitor, event: event) }

      before do
        create(:exhibitor_kit_payment, :verified,
               exhibitor_kit: exhibitor1.exhibitor_kit,
               payee: contractor,
               amount: 100.00)
        create(:exhibitor_kit_payment, :verified,
               exhibitor_kit: exhibitor2.exhibitor_kit,
               payee: contractor,
               amount: 200.00)
      end

      it 'counts distinct exhibitors correctly' do
        get '/v1/contractor/dashboard', headers: auth_headers(contractor)

        expect(json_body['summary']['total_exhibitors']).to eq(2)
        expect(json_body['summary']['total_received_amount']).to eq(300.0)
      end
    end

    context 'as exhibition contractor without profile' do
      let(:contractor_no_profile) { create(:user, :exhibition_contractor, with_profile: false) }

      it 'returns empty dashboard' do
        get '/v1/contractor/dashboard', headers: auth_headers(contractor_no_profile)

        expect(response).to have_http_status(:ok)
        expect(json_body['summary']['total_events']).to eq(0)
        expect(json_body['events']).to eq([])
      end
    end

    context 'as org_owner (non-contractor role)' do
      it 'returns forbidden' do
        get '/v1/contractor/dashboard', headers: auth_headers(org_owner)

        expect(response).to have_http_status(:forbidden)
        expect(json_body['error']).to include('Exhibition contractor role required')
      end
    end

    context 'as vendor (non-contractor role)' do
      it 'returns forbidden' do
        get '/v1/contractor/dashboard', headers: auth_headers(vendor_user)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without authentication' do
      it 'returns unauthorized' do
        get '/v1/contractor/dashboard'

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'contractor only sees their own payments' do
      let!(:other_contractor) { create(:user, :exhibition_contractor, with_profile: false) }
      let!(:other_profile) { create(:exhibition_contractor_profile, user: other_contractor) }
      let!(:event) { create(:event, status: :published) }
      let!(:event_contractor) do
        create(:event_exhibition_contractor,
               event: event,
               exhibition_contractor_profile: contractor_profile)
      end
      let!(:exhibitor) { create(:exhibitor, event: event) }

      before do
        # Payment to current contractor
        create(:exhibitor_kit_payment, :verified,
               exhibitor_kit: exhibitor.exhibitor_kit,
               payee: contractor,
               amount: 100.00)
        # Payment to other contractor (should not be included)
        create(:exhibitor_kit_payment, :verified,
               exhibitor_kit: exhibitor.exhibitor_kit,
               payee: other_contractor,
               amount: 999.00)
      end

      it 'only includes payments where contractor is the payee' do
        get '/v1/contractor/dashboard', headers: auth_headers(contractor)

        expect(json_body['summary']['total_received_amount']).to eq(100.0)
        expect(json_body['summary']['verified_payments_count']).to eq(1)
      end
    end
  end

  private

  def json_body
    JSON.parse(response.body)
  end
end
