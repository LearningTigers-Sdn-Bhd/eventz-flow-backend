# spec/requests/v1/vendor_dashboard_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::VendorDashboard', type: :request do
  # --- Setup Users & Tokens ---
  let(:vendor_user) { create(:vendor_user) }
  let(:other_vendor_user) { create(:vendor_user) }
  let(:member_user) { create(:member_user) }

  let(:vendor_token) { JwtService.generate_tokens(vendor_user)[:access_token] }
  let(:other_vendor_token) { JwtService.generate_tokens(other_vendor_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Events ---
  let!(:event1) { create(:event, status: :published, use_ticket: false) }
  let!(:event2) { create(:event, status: :published, use_ticket: false) }
  let!(:event3) { create(:event, status: :draft, use_ticket: false) }

  # --- Setup Event Vendors ---
  let!(:event_vendor1) { create(:event_vendor, event: event1, vendor: vendor_user) }
  let!(:event_vendor2) { create(:event_vendor, event: event2, vendor: vendor_user) }
  let!(:event_vendor3) { create(:event_vendor, event: event3, vendor: vendor_user) }
  let!(:other_event_vendor) { create(:event_vendor, event: event1, vendor: other_vendor_user) }

  # --- Setup Visitors and Stamps ---
  let!(:visitor1) { create(:visitor, event: event1) }
  let!(:visitor2) { create(:visitor, event: event1) }
  let!(:visitor3) { create(:visitor, event: event2) }

  let!(:stamp1) { create(:visitor_vendor_stamp, visitor: visitor1, event_vendor: event_vendor1) }
  let!(:stamp2) { create(:visitor_vendor_stamp, visitor: visitor2, event_vendor: event_vendor1) }
  let!(:stamp3) { create(:visitor_vendor_stamp, visitor: visitor3, event_vendor: event_vendor2) }
  let!(:other_stamp) { create(:visitor_vendor_stamp, visitor: visitor1, event_vendor: other_event_vendor) }

  # --- Setup Vouchers ---
  let!(:voucher1) { create(:voucher, event: event1, vendor: vendor_user, total_redemption_available: 100) }
  let!(:voucher2) { create(:voucher, event: event1, vendor: vendor_user, total_redemption_available: 50) }
  let!(:voucher3) { create(:voucher, event: event2, vendor: vendor_user, total_redemption_available: 75) }
  let!(:other_voucher) { create(:voucher, event: event1, vendor: other_vendor_user, total_redemption_available: 200) }

  # --- Setup Redemption Logs ---
  let!(:redemption1) { create(:voucher_redemption_log, voucher: voucher1) }
  let!(:redemption2) { create(:voucher_redemption_log, voucher: voucher1) }
  let!(:redemption3) { create(:voucher_redemption_log, voucher: voucher2) }
  let!(:redemption4) { create(:voucher_redemption_log, voucher: voucher3) }
  let!(:other_redemption) { create(:voucher_redemption_log, voucher: other_voucher) }

  path '/v1/vendor/dashboard' do
    get 'Get vendor dashboard data' do
      tags 'Vendor Dashboard'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Dashboard data retrieved successfully' do
        schema type: :object,
               properties: {
                 summary: {
                   type: :object,
                   properties: {
                     total_events: { type: :integer },
                     active_events: { type: :integer },
                     total_stamps: { type: :integer },
                     total_vouchers: { type: :integer },
                     total_redeemed: { type: :integer }
                   }
                 },
                 events: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       title: { type: :string },
                       status: { type: :string },
                       use_ticket: { type: :boolean },
                       start_date: { type: :string },
                       end_date: { type: :string },
                       event_vendor_id: { type: :integer },
                       stamp_count: { type: :integer },
                       total_vouchers: { type: :integer },
                       total_redeemed: { type: :integer },
                       redemption_rate: { type: :number }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{vendor_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)

          # Verify summary
          expect(data['summary']['total_events']).to eq(3)
          expect(data['summary']['active_events']).to eq(2)
          expect(data['summary']['total_stamps']).to eq(3)
          expect(data['summary']['total_vouchers']).to eq(225)
          expect(data['summary']['total_redeemed']).to eq(4)

          # Verify events array
          expect(data['events'].length).to eq(3)

          # Verify event1 data
          event1_data = data['events'].find { |e| e['id'] == event1.id }
          expect(event1_data['stamp_count']).to eq(2)
          expect(event1_data['total_vouchers']).to eq(150)
          expect(event1_data['total_redeemed']).to eq(3)
          expect(event1_data['redemption_rate']).to eq(2.0)

          # Verify event2 data
          event2_data = data['events'].find { |e| e['id'] == event2.id }
          expect(event2_data['stamp_count']).to eq(1)
          expect(event2_data['total_vouchers']).to eq(75)
          expect(event2_data['total_redeemed']).to eq(1)

          # Verify event3 data (draft)
          event3_data = data['events'].find { |e| e['id'] == event3.id }
          expect(event3_data['stamp_count']).to eq(0)
          expect(event3_data['total_vouchers']).to eq(0)
          expect(event3_data['total_redeemed']).to eq(0)
        end
      end

      response '200', 'Empty dashboard for vendor with no events' do
        let(:new_vendor) { create(:vendor_user) }
        let(:new_vendor_token) { JwtService.generate_tokens(new_vendor)[:access_token] }
        let(:Authorization) { "Bearer #{new_vendor_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['summary']['total_events']).to eq(0)
          expect(data['summary']['active_events']).to eq(0)
          expect(data['summary']['total_stamps']).to eq(0)
          expect(data['summary']['total_vouchers']).to eq(0)
          expect(data['summary']['total_redeemed']).to eq(0)
          expect(data['events']).to be_empty
        end
      end

      response '200', 'Vendor only sees their own data' do
        let(:Authorization) { "Bearer #{other_vendor_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)

          # other_vendor_user only has event_vendor for event1
          expect(data['summary']['total_events']).to eq(1)
          expect(data['summary']['total_stamps']).to eq(1)
          expect(data['summary']['total_vouchers']).to eq(200)
          expect(data['summary']['total_redeemed']).to eq(1)

          # Should only see event1
          expect(data['events'].length).to eq(1)
          expect(data['events'].first['id']).to eq(event1.id)
        end
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  # =========================================================================
  # Email Verification Requirement Tests
  # =========================================================================

  describe 'Email Verification Enforcement' do
    let(:unverified_user) { create(:user, :unverified, role: :vendor) }
    let(:unverified_token) { JwtService.generate_tokens(unverified_user)[:access_token] }

    context 'when unverified user tries to access vendor dashboard' do
      it 'returns 403 Forbidden' do
        get '/v1/vendor/dashboard', headers: { 'Authorization' => "Bearer #{unverified_token}" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Email verification required')
      end
    end
  end

  # =========================================================================
  # Edge Cases
  # =========================================================================

  describe 'Edge cases' do
    context 'when vendor has vouchers with zero total_redemption_available' do
      let(:vendor_with_zero_vouchers) { create(:vendor_user) }
      let(:zero_voucher_token) { JwtService.generate_tokens(vendor_with_zero_vouchers)[:access_token] }
      let!(:event) { create(:event, status: :published, use_ticket: false) }
      let!(:ev) { create(:event_vendor, event: event, vendor: vendor_with_zero_vouchers) }
      let!(:zero_voucher) { create(:voucher, event: event, vendor: vendor_with_zero_vouchers, total_redemption_available: 0) }

      it 'returns 0 redemption_rate without division error' do
        get '/v1/vendor/dashboard', headers: { 'Authorization' => "Bearer #{zero_voucher_token}" }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        event_data = data['events'].find { |e| e['id'] == event.id }
        expect(event_data['redemption_rate']).to eq(0)
      end
    end
  end
end
