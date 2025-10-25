# analytics_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Analytics', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:staff_user) { create(:staff_user) }
  let(:member_user) { create(:member_user) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:manager_token) { JwtService.generate_tokens(manager_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup Events and Tickets ---
  let!(:event1) { create(:event, status: :published, visibility: true) }
  let!(:event2) { create(:event, status: :published, visibility: true) }
  let!(:event3) { create(:event, status: :draft, visibility: true) }
  let!(:ticket_type1) { create(:ticket_type, event: event1, price: 50.00) }
  let!(:ticket_type2) { create(:ticket_type, event: event2, price: 75.00) }

  # Create tickets across multiple events
  let!(:event1_tickets) { create_list(:ticket, 3, event: event1, ticket_type: ticket_type1, status: :purchased) }
  let!(:event1_scanned) { create_list(:ticket, 2, event: event1, ticket_type: ticket_type1, status: :scanned, checked_in: true) }
  let!(:event2_tickets) { create_list(:ticket, 4, event: event2, ticket_type: ticket_type2, status: :purchased) }
  let!(:event2_scanned) { create_list(:ticket, 1, event: event2, ticket_type: ticket_type2, status: :scanned, checked_in: true) }

  # Create event locations for testing
  let!(:event1_location1) { create(:event_location, event: event1) }
  let!(:event1_location2) { create(:event_location, event: event1) }
  let!(:event2_location1) { create(:event_location, event: event2) }

  # Assign users to events
  before do
    # Staff user has access to event1 only
    EventAssignment.find_or_create_by!(event: event1, user: staff_user, role: :event_admin)

    # Manager user has access to all events (event1, event2, event3)
    EventAssignment.find_or_create_by!(event: event1, user: manager_user, role: :event_admin)
    EventAssignment.find_or_create_by!(event: event2, user: manager_user, role: :event_admin)
    EventAssignment.find_or_create_by!(event: event3, user: manager_user, role: :event_admin)
  end

  # ===================================================================
  # OPTIMIZED BULK ENDPOINTS (Works for all roles)
  # ===================================================================

  path '/v1/analytics/events_overview' do
    get 'Get all accessible events with their analytics data' do
      tags 'Optimized Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Events overview retrieved successfully for org_owner' do
        schema type: :object,
               properties: {
                 events: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       id: { type: :integer },
                       title: { type: :string },
                       status: { type: :string },
                       total_tickets: { type: :integer, description: 'Total active tickets (purchased + scanned)' },
                       scanned_tickets: { type: :integer, description: 'Total checked-in tickets' },
                       unscanned_tickets: { type: :integer, description: 'Total unscanned active tickets' },
                       total_revenue: { type: :integer, description: 'Total revenue in cents' },
                       last_activity: { type: :string, format: 'date-time' }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['events']).to be_an(Array)
          expect(data['events'].length).to eq(3) # event1, event2, event3

          # Check event1 data
          event1_data = data['events'].find { |e| e['id'] == event1.id }
          expect(event1_data['total_tickets']).to eq(5) # 3 purchased + 2 scanned
          expect(event1_data['scanned_tickets']).to eq(2)
          expect(event1_data['unscanned_tickets']).to eq(3)
          expect(event1_data['total_revenue']).to eq(25000) # 5 * 50.00 * 100
        end
      end

      response '200', 'Events overview retrieved successfully for manager (all assigned events)' do
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['events']).to be_an(Array)
          expect(data['events'].length).to eq(3) # All events assigned to manager
        end
      end

      response '200', 'Events overview retrieved successfully for staff (scoped to assigned events)' do
        let(:Authorization) { "Bearer #{staff_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['events']).to be_an(Array)
          expect(data['events'].length).to eq(1) # Only event1
          expect(data['events'].first['id']).to eq(event1.id)
        end
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  path '/v1/analytics/summary' do
    get 'Get aggregated analytics summary across all accessible events' do
      tags 'Optimized Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Analytics summary retrieved successfully for org_owner' do
        schema type: :object,
               properties: {
                 total_events: { type: :integer, description: 'Total number of accessible events' },
                 active_events: { type: :integer, description: 'Number of published events' },
                 total_tickets: { type: :integer, description: 'Total active tickets (purchased + scanned)' },
                 total_scanned: { type: :integer, description: 'Total checked-in tickets' },
                 total_revenue: { type: :integer, description: 'Total revenue in cents' },
                 total_locations: { type: :integer, description: 'Total event locations' }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['total_events']).to eq(3) # event1, event2, event3
          expect(data['active_events']).to eq(2) # event1, event2 (published)
          expect(data['total_tickets']).to eq(10) # 3 + 2 + 4 + 1
          expect(data['total_scanned']).to eq(3) # 2 + 1
          expect(data['total_revenue']).to eq(62500) # (5 * 50.00 + 5 * 75.00) * 100
          expect(data['total_locations']).to eq(6) # event1: 3, event2: 2, event3: 1 (factory auto-creates 1 per event)
        end
      end

      response '200', 'Analytics summary retrieved successfully for manager (all assigned events)' do
        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['total_events']).to eq(3) # All events assigned to manager
          expect(data['active_events']).to eq(2) # event1, event2 (published)
          expect(data['total_tickets']).to eq(10)
          expect(data['total_scanned']).to eq(3)
          expect(data['total_revenue']).to eq(62500)
        end
      end

      response '200', 'Analytics summary retrieved successfully for staff (scoped to assigned events)' do
        let(:Authorization) { "Bearer #{staff_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['total_events']).to eq(1) # Only event1
          expect(data['active_events']).to eq(1) # Only event1 (published)
          expect(data['total_tickets']).to eq(5) # event1 tickets only
          expect(data['total_scanned']).to eq(2) # event1 scanned only
          expect(data['total_revenue']).to eq(25000) # event1 revenue only
          expect(data['total_locations']).to eq(3) # event1: 1 (auto) + 2 (manual) = 3 locations
        end
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end

  # ===================================================================
  # EXISTING GLOBAL ENDPOINTS (Requires org_owner/manager)
  # ===================================================================

  path '/v1/analytics/total_tickets' do
    get 'Get total tickets count across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalTickets: { type: :integer, description: 'Total number of active tickets across all events' }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalTickets']).to eq(10) # 3 + 2 + 4 + 1 = 10 total active tickets
        end
      end

      response '403', 'Forbidden - insufficient permissions' do
        let(:Authorization) { "Bearer #{staff_token}" }

        run_test!
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { nil }

        run_test!
      end
    end
  end

  path '/v1/analytics/total_scanned_tickets' do
    get 'Get total scanned tickets count across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total scanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalScannedTickets: { type: :integer, description: 'Total number of scanned tickets across all events' }
               }

        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalScannedTickets']).to eq(3) # 2 + 1 = 3 scanned tickets
        end
      end
    end
  end

  path '/v1/analytics/total_unscanned_tickets' do
    get 'Get total unscanned tickets count across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total unscanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalUnscannedTickets: { type: :integer, description: 'Total number of unscanned tickets across all events' }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalUnscannedTickets']).to eq(7) # 10 total - 3 scanned
        end
      end
    end
  end

  path '/v1/analytics/total_amount_price' do
    get 'Get total sales amount across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total sales amount retrieved successfully' do
        schema type: :object,
               properties: {
                 totalAmountPrice: { type: :integer, description: 'Total sales amount in cents across all events' }
               }

        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          # Event1: 5 tickets * 50.00 = 25000 cents
          # Event2: 5 tickets * 75.00 = 37500 cents
          # Total: 62500 cents
          expect(data['totalAmountPrice']).to eq(62500)
        end
      end
    end
  end

  path '/v1/analytics/weekly_registered_tickets' do
    get 'Get weekly registered tickets data across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly registered tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklyRegisteredTickets: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date, description: 'Date in YYYY-MM-DD format' },
                       count: { type: :integer, description: 'Number of tickets registered on this date' }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklyRegisteredTickets']).to be_an(Array)
          expect(data['weeklyRegisteredTickets'].length).to eq(7)
          expect(data['weeklyRegisteredTickets'].first).to have_key('date')
          expect(data['weeklyRegisteredTickets'].first).to have_key('count')
        end
      end
    end
  end

  path '/v1/analytics/weekly_scanned_tickets' do
    get 'Get weekly scanned tickets data across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly scanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklyScannedTickets: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date, description: 'Date in YYYY-MM-DD format' },
                       count: { type: :integer, description: 'Number of tickets scanned on this date' }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{manager_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklyScannedTickets']).to be_an(Array)
          expect(data['weeklyScannedTickets'].length).to eq(7)
        end
      end
    end
  end

  path '/v1/analytics/weekly_sales_amount' do
    get 'Get weekly sales amount data across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Weekly sales amount retrieved successfully' do
        schema type: :object,
               properties: {
                 weeklySalesAmount: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       date: { type: :string, format: :date, description: 'Date in YYYY-MM-DD format' },
                       count: { type: :integer, description: 'Sales amount in cents for this date' }
                     }
                   }
                 }
               }

        let(:Authorization) { "Bearer #{org_owner_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['weeklySalesAmount']).to be_an(Array)
          expect(data['weeklySalesAmount'].length).to eq(7)
        end
      end
    end
  end
end
