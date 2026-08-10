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
  let(:ticket_created_at) { event.start_date + 1.hour }

  # Create paid, pending, and ineligible tickets on the same RM50 ticket type.
  let!(:purchased_tickets) do
    create_list(:ticket, 5, :paid, event: event, ticket_type: ticket_type,
                                 status: :purchased, created_at: ticket_created_at)
  end
  let!(:scanned_tickets) do
    create_list(:ticket, 3, :paid, event: event, ticket_type: ticket_type,
                                 status: :scanned, checked_in: true, created_at: ticket_created_at)
  end
  let!(:pending_ticket) do
    create(:ticket, :pending_payment, event: event, ticket_type: ticket_type, checked_in: true,
                                     created_at: ticket_created_at)
  end
  let!(:legacy_pending_ticket) do
    create(:ticket, event: event, ticket_type: ticket_type, status: :purchased,
                    payment_status: :pending, created_at: ticket_created_at)
  end
  let!(:failed_ticket) do
    create(:ticket, event: event, ticket_type: ticket_type, status: :purchased,
                    payment_status: :failed, created_at: ticket_created_at)
  end
  let!(:refunded_tickets) do
    create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :refunded,
                             payment_status: :refunded_payment, created_at: ticket_created_at)
  end
  let!(:canceled_ticket) do
    create(:ticket, event: event, ticket_type: ticket_type, status: :canceled,
                    payment_status: :pending, created_at: ticket_created_at)
  end

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
                 totalTickets: { type: :integer },
                 paidTickets: { type: :integer },
                 pendingTickets: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalTickets']).to eq(10)
          expect(data['paidTickets']).to eq(8)
          expect(data['pendingTickets']).to eq(2)
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
          expect(data['totalUnscannedTickets']).to eq(5)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_visitors' do
    get 'Get total visitors count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total visitors retrieved successfully' do
        schema type: :object,
               properties: {
                 totalVisitors: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          create_list(:visitor, 5, event: event)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalVisitors']).to eq(5)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_scanned_visitors' do
    get 'Get total scanned visitors count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total scanned visitors retrieved successfully' do
        schema type: :object,
               properties: {
                 totalScannedVisitors: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          create_list(:visitor, 3, event: event, checked_in: false)
          create_list(:visitor, 2, event: event, checked_in: true)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalScannedVisitors']).to eq(2)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/total_unscanned_visitors' do
    get 'Get total unscanned visitors count for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total unscanned visitors retrieved successfully' do
        schema type: :object,
               properties: {
                 totalUnscannedVisitors: { type: :integer }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          create_list(:visitor, 4, event: event, checked_in: false)
          create_list(:visitor, 2, event: event, checked_in: true)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalUnscannedVisitors']).to eq(4)
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
                 totalAmountPrice: { type: :integer, description: 'Amount in cents' },
                 pendingAmountPrice: { type: :integer, description: 'Amount in cents' }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalAmountPrice']).to eq(40000)
          expect(data['pendingAmountPrice']).to eq(10000)
        end
      end
    end
  end

  path '/v1/events/{event_id}/metrics/exhibitor_analytics' do
    get 'Get exhibitor or vendor analytics for an event' do
      tags 'Event Analytics'
      produces 'application/json'
      parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Exhibitor analytics retrieved successfully' do
        schema type: :object,
               properties: {
                 mode: { type: :string, enum: %w[exhibitor vendor] },
                 totalPartners: { type: :integer },
                 paidPartners: { type: :integer },
                 unpaidPartners: { type: :integer },
                 collectedRevenue: { type: :number },
                 pendingRevenue: { type: :number },
                 breakdown: { type: :array, items: { type: :object } },
                 vendorMetrics: { type: :object }
               }

        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          event.update!(use_exhibitor_kit: true)

          shell_zone = create(:exhibitor_zone, event: event, zone: 'zone_shell')
          raw_zone = create(:exhibitor_zone, event: event, zone: 'zone_raw')
          shell_scheme = create(:exhibitor_booth_price, event: event,
                                exhibitor_zone: shell_zone, booth_type: 'shell_scheme',
                                label: 'Shell Scheme', price: 1000)
          raw_space = create(:exhibitor_booth_price, event: event,
                             exhibitor_zone: raw_zone, booth_type: 'raw_space',
                             label: 'Raw Space', price: 750)

          paid_exhibitor = create(:exhibitor, event: event)
          paid_kit = create(:exhibitor_kit, event_vendor: paid_exhibitor,
                            exhibitor_booth_price: shell_scheme, booth_type: 'shell_scheme',
                            booth_quantity: 2, amount_paid: 2000, price_snapshot: 1000,
                            payment_status: :paid, booking_status: :paid)
          create(:exhibitor_registration_payment, exhibitor_kit: paid_kit,
                 amount: 2000, status: 'paid')

          unpaid_exhibitor = create(:exhibitor, event: event)
          create(:exhibitor_kit, event_vendor: unpaid_exhibitor,
                 exhibitor_booth_price: raw_space, booth_type: 'raw_space', booth_quantity: 1,
                 amount_paid: 750, price_snapshot: 750,
                 payment_status: :unpaid, booking_status: :active)

          waived_exhibitor = create(:exhibitor, event: event)
          create(:exhibitor_kit, event_vendor: waived_exhibitor,
                 exhibitor_booth_price: raw_space, booth_type: 'raw_space', booth_quantity: 1,
                 amount_paid: 750, price_snapshot: 750,
                 payment_status: :waived, booking_status: :active)

          sponsored_exhibitor = create(:exhibitor, event: event)
          create(:exhibitor_kit, event_vendor: sponsored_exhibitor,
                 exhibitor_booth_price: raw_space, booth_type: 'raw_space', booth_quantity: 1,
                 amount_paid: 750, price_snapshot: 750,
                 payment_status: :sponsored, booking_status: :active)
        end

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['mode']).to eq('exhibitor')
          expect(data['totalPartners']).to eq(4)
          expect(data['paidPartners']).to eq(3)
          expect(data['unpaidPartners']).to eq(1)
          expect(data['collectedRevenue']).to eq(2000.0)
          expect(data['pendingRevenue']).to eq(750.0)

          breakdown = data['breakdown'].index_by { |row| row['label'] }
          expect(breakdown['Shell Scheme']).to include(
            'zone' => 'zone_shell',
            'bookedQuantity' => 2,
            'paidQuantity' => 2,
            'unpaidQuantity' => 0,
            'collectedRevenue' => 2000.0,
            'pendingRevenue' => 0.0
          )
          expect(breakdown['Raw Space']).to include(
            'zone' => 'zone_raw',
            'bookedQuantity' => 3,
            'paidQuantity' => 2,
            'unpaidQuantity' => 1,
            'collectedRevenue' => 0.0,
            'pendingRevenue' => 750.0
          )
        end
      end

      response '200', 'Vendor analytics retrieved for non-exhibitor events' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          event.update!(use_exhibitor_kit: false)
          create(:merchant, event: event)
        end

        run_test! do |response|
          data = JSON.parse(response.body)

          expect(data['mode']).to eq('vendor')
          expect(data['totalPartners']).to eq(1)
          expect(data['vendorMetrics']).to include(
            'totalLeads' => 0,
            'voucherSales' => 0.0,
            'voucherRedemptions' => 0
          )
          expect(data['breakdown']).to eq([])
        end
      end

      response '200', 'Exhibitor breakdown rows have unique identifiers' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          event.update!(use_exhibitor_kit: true)

          first_zone = create(:exhibitor_zone, event: event, zone: 'zone_first')
          second_zone = create(:exhibitor_zone, event: event, zone: 'zone_second')
          first_price = create(:exhibitor_booth_price, event: event,
                               exhibitor_zone: first_zone, booth_type: 'shell_scheme',
                               label: 'Standard Booth', price: 1000)
          second_price = create(:exhibitor_booth_price, event: event,
                                exhibitor_zone: second_zone, booth_type: 'shell_scheme',
                                label: 'Standard Booth', price: 1200)

          first_exhibitor = create(:exhibitor, event: event)
          create(:exhibitor_kit, event_vendor: first_exhibitor,
                 exhibitor_booth_price: first_price, booth_type: 'shell_scheme',
                 booth_quantity: 1, amount_paid: 1000, price_snapshot: 1000,
                 payment_status: :unpaid, booking_status: :active)
          second_exhibitor = create(:exhibitor, event: event)
          create(:exhibitor_kit, event_vendor: second_exhibitor,
                 exhibitor_booth_price: second_price, booth_type: 'shell_scheme',
                 booth_quantity: 1, amount_paid: 1200, price_snapshot: 1200,
                 payment_status: :unpaid, booking_status: :active)
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          keys = data['breakdown'].map { |row| row['breakdownKey'] }

          expect(keys).to all(be_a(String))
          expect(keys.uniq.length).to eq(keys.length)
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
            create(:event_lead, event_vendor: event_vendor, leadable: create(:visitor, event: event))
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
      parameter name: :date_mode, in: :query, type: :string, required: false,
                description: 'Date mode: all_time (from first registration), pre_event (before event start)'
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
          expect(data['data'].sum { |point| point['value'] }).to eq(10)
          expect(data['start_date']).to be_present
          expect(data['end_date']).to be_present
        end
      end

      response '200', 'Excludes pending ticket revenue from the time series' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:metric) { 'revenue' }
        let(:group_by) { 'day' }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['metric']).to eq('revenue')
          expect(data['data'].sum { |point| point['value'] }).to eq(40000)
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

      response '200', 'Returns all_time data including pre-event registrations' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:metric) { 'tickets' }
        let(:date_mode) { 'all_time' }

        before do
          # Create tickets before the event start date
          travel_to(event.start_date - 7.days) do
            create_list(:ticket, 3, event: event, ticket_type: ticket_type, status: :purchased)
          end
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['metric']).to eq('tickets')
          expect(data['data']).to be_an(Array)
          # Start date should be earlier than event start_date (from first registration)
          expect(Date.parse(data['start_date'])).to be <= event.start_date.to_date
        end
      end

      response '200', 'Returns pre_event data only before event start' do
        let(:event_id) { event.id }
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:metric) { 'tickets' }
        let(:date_mode) { 'pre_event' }

        before do
          # Create tickets before the event start date
          travel_to(event.start_date - 5.days) do
            create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :purchased)
          end
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['metric']).to eq('tickets')
          expect(data['data']).to be_an(Array)
          # End date should be the event start date
          expect(Date.parse(data['end_date'])).to eq(event.start_date.to_date)
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
