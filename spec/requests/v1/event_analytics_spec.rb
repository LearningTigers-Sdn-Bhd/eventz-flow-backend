# event_analytics_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::EventAnalytics', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:staff_user) { create(:user, :staff_member) }
  let(:member_user) { create(:user, :member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Event and Tickets ---
  let(:event) { create(:event, status: :published) }
  let(:ticket_type) { create(:ticket_type, event: event, price: 50.00) }

  # Create tickets with different statuses and check-in states
  let!(:purchased_tickets) { create_list(:ticket, 5, event: event, ticket_type: ticket_type, status: :purchased) }
  let!(:scanned_tickets) { create_list(:ticket, 3, event: event, ticket_type: ticket_type, status: :scanned, checked_in: true) }
  let!(:refunded_tickets) { create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :refunded) }

  # Assign users to event
  before do
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    EventAssignment.find_or_create_by!(event: event, user: staff_user, role: :event_team_member)
  end

  path '/v1/events/{event_id}/metrics/total_tickets' do
    get 'Get total tickets count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalTickets: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalTickets']).to eq(8) # 5 purchased + 3 scanned (excludes refunded)
        end
      end

      response '403', 'Forbidden - insufficient permissions' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{member_token}" }

        run_test!
      end

      response '404', 'Event not found' do
        let(:event_id) { 99999 }
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_scanned_tickets' do
    get 'Get total scanned tickets count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total scanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalScannedTickets: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalScannedTickets']).to eq(3)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_unscanned_tickets' do
    get 'Get total unscanned tickets count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total unscanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalUnscannedTickets: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalUnscannedTickets']).to eq(5) # 8 total - 3 scanned
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_amount_price' do
    get 'Get total sales amount for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total sales amount retrieved successfully' do
        schema type: :object,
               properties: {
                 totalAmountPrice: { type: :integer, description: 'Amount in cents' }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalAmountPrice']).to eq(40000) # 8 tickets * 50.00 * 100 cents
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/mall_live_feed' do
    get 'Get live feed dashboard data' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Live feed data retrieved successfully' do
        schema type: :object,
               properties: {
                 shoppers_registered_today: { type: :integer },
                 estimated_sales_today: { type: :string },
                 voucher_issuances: { type: :integer },
                 voucher_redemptions: { type: :integer },
                 redemption_rate: { type: :number },
                 top_merchants: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       name: { type: :string },
                       count: { type: :integer }
                     }
                   }
                 },
                 popular_halls: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       name: { type: :string },
                       percentage: { type: :number }
                     }
                   }
                 }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          create_list(:visitor, 3, event: event, created_at: Time.zone.now)

          voucher = create(:voucher, event: event, total_redemption_available: 100)
          create_list(:voucher_redemption_log, 2,
            voucher: voucher,
            transaction_net_amount: 50.0,
            redemption_timestamp: Time.zone.now,
            redeemer: create(:visitor, event: event),
            redemption_status: 'completed',
            transaction_gross_amount: 50.0,
            discount_applied_value: 0.0
          )

          vendor_user = create(:user, :vendor)
          event_vendor = create(:event_vendor, event: event, vendor: vendor_user)

          location = create(:event_location, event: event, name: "Hall A")
          create(:event_location_member, event_location: location, member: vendor_user)

          4.times do
            create(:visitor_vendor_stamp, event_vendor: event_vendor, visitor: create(:visitor, event: event))
          end
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['shoppers_registered_today']).to eq(8)
          expect(data['estimated_sales_today'].to_f).to eq(100.0)
          expect(data['voucher_issuances']).to eq(100)
          expect(data['voucher_redemptions']).to eq(2)
          expect(data['redemption_rate']).to eq(2.0)
          expect(data['top_merchants'].length).to eq(1)
          expect(data['top_merchants'][0]['count']).to eq(4)

          expect(data['popular_halls']).to be_an(Array)
          expect(data['popular_halls'].length).to eq(1)
          expect(data['popular_halls'][0]['name']).to eq("Hall A")
          expect(data['popular_halls'][0]['percentage']).to eq(100.0)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/time_series' do
    get 'Get flexible time-series analytics data' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'
      parameter name: :metric, in: :query, type: :string, required: true,
                description: 'Metric to retrieve: tickets, scans, revenue, visitors, stamps, redemptions, redemption_value'
      parameter name: :group_by, in: :query, type: :string, required: false,
                description: 'Time grouping: hour, day, week, month (auto-detected if not provided)'
      parameter name: :start_date, in: :query, type: :string, required: false,
                description: 'Start date (YYYY-MM-DD), defaults to event start_date'
      parameter name: :end_date, in: :query, type: :string, required: false,
                description: 'End date (YYYY-MM-DD), defaults to event end_date'

      response '200', 'Time series data retrieved successfully' do
        schema type: :object,
               properties: {
                 metric: { type: :string },
                 group_by: { type: :string },
                 start_date: { type: :string, format: :date },
                 end_date: { type: :string, format: :date },
                 data: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       period: { type: :string },
                       value: { type: :integer }
                     }
                   }
                 }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:metric) { 'tickets' }
        let(:group_by) { 'day' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['metric']).to eq('tickets')
          expect(data['group_by']).to eq('day')
          expect(data['data']).to be_an(Array)
          expect(data['start_date']).to be_present
          expect(data['end_date']).to be_present
        end
      end

      response '200', 'Auto-detects group_by based on event duration' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:metric) { 'visitors' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['metric']).to eq('visitors')
          expect(data['group_by']).to be_present
          expect(data['data']).to be_an(Array)
        end
      end

      response '400', 'Missing required metric parameter' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:metric) { '' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to include('metric')
        end
      end

      response '400', 'Invalid metric parameter' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:metric) { 'invalid_metric' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to include('Invalid metric')
        end
      end

      response '403', 'Forbidden - insufficient permissions' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{member_token}" }
        let(:metric) { 'tickets' }

        run_test!
      end
    end
  end
end
