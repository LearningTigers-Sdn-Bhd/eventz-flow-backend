# analytics_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Analytics', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:staff_user) { create(:user, :staff_member) }
  let(:member_user) { create(:user, :member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
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

    # Organizer user has access to all events (event1, event2, event3)
    EventAssignment.find_or_create_by!(event: event1, user: organizer_user, role: :event_admin)
    EventAssignment.find_or_create_by!(event: event2, user: organizer_user, role: :event_admin)
    EventAssignment.find_or_create_by!(event: event3, user: organizer_user, role: :event_admin)
  end

  # ===================================================================
  # OPTIMIZED BULK ENDPOINTS (Works for all roles)
  # ===================================================================

  path '/v1/metrics/events_overview' do
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

      response '200', 'Events overview retrieved successfully for organizer (all assigned events)' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['events']).to be_an(Array)
          expect(data['events'].length).to eq(3) # All events assigned to organizer
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

  path '/v1/metrics/summary' do
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

      response '200', 'Analytics summary retrieved successfully for organizer (all assigned events)' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['total_events']).to eq(3) # All events assigned to organizer
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

    # Additional edge case tests for summary
    context 'Edge cases for summary' do
      let(:summary_edge_case_user) { create(:user, :org_owner) }
      let(:summary_edge_case_token) { JwtService.generate_tokens(summary_edge_case_user)[:access_token] }

      # Clear existing events to isolate test data
      before do
        Ticket.destroy_all
        TicketType.destroy_all
        EventLocation.destroy_all
        EventAssignment.destroy_all
        Event.destroy_all
      end

      it 'handles empty summary when user has no events' do
        isolated_user = create(:user, :org_owner)
        isolated_token = JwtService.generate_tokens(isolated_user)[:access_token]

        get '/v1/metrics/summary', params: {}, headers: {
          'Authorization' => "Bearer #{isolated_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['total_events']).to eq(0)
        expect(data['active_events']).to eq(0)
        expect(data['total_tickets']).to eq(0)
        expect(data['total_scanned']).to eq(0)
        expect(data['total_revenue']).to eq(0)
        expect(data['total_locations']).to eq(0)
      end

      it 'excludes refunded and canceled tickets from summary calculations' do
        event = create(:event, status: :published, visibility: true)
        ticket_type = create(:ticket_type, event: event, price: 50.00)

        # Active tickets (should be counted)
        create_list(:ticket, 5, event: event, ticket_type: ticket_type, status: :purchased)
        create_list(:ticket, 3, event: event, ticket_type: ticket_type, status: :scanned, checked_in: true)

        # Should be excluded
        create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :refunded)
        create_list(:ticket, 1, event: event, ticket_type: ticket_type, status: :canceled)

        get '/v1/metrics/summary', params: {}, headers: {
          'Authorization' => "Bearer #{summary_edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['total_tickets']).to eq(8) # 5 purchased + 3 scanned
        expect(data['total_scanned']).to eq(3)
        expect(data['total_revenue']).to eq(40000) # 8 * 50.00 * 100
      end

      it 'calculates revenue correctly with multiple events and ticket types' do
        event1 = create(:event, status: :published, visibility: true)
        event2 = create(:event, status: :published, visibility: true)

        tt1 = create(:ticket_type, event: event1, price: 30.00)
        tt2 = create(:ticket_type, event: event2, price: 75.50)

        create_list(:ticket, 4, event: event1, ticket_type: tt1, status: :purchased)
        create_list(:ticket, 6, event: event2, ticket_type: tt2, status: :purchased)

        get '/v1/metrics/summary', params: {}, headers: {
          'Authorization' => "Bearer #{summary_edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['total_events']).to eq(2)
        expect(data['active_events']).to eq(2)
        expect(data['total_tickets']).to eq(10)
        # 4 * 30.00 + 6 * 75.50 = 120.00 + 453.00 = 573.00 * 100 = 57300
        expect(data['total_revenue']).to eq(57300)
      end

      it 'includes paid exhibitor registration revenue in summary total_revenue' do
        event = create(:event, status: :published, visibility: true)
        ticket_type = create(:ticket_type, event: event, price: 50.00)
        create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :purchased)

        exhibitor = create(:exhibitor, :with_exhibitor_kit, event: event)
        create(
          :exhibitor_registration_payment,
          exhibitor_kit: exhibitor.exhibitor_kit,
          amount: 1200.50,
          status: "paid",
        )

        another_exhibitor = create(:exhibitor, :with_exhibitor_kit, event: event)
        create(
          :exhibitor_registration_payment,
          exhibitor_kit: another_exhibitor.exhibitor_kit,
          amount: 300,
          status: "pending",
        )

        get '/v1/metrics/summary', params: {}, headers: {
          'Authorization' => "Bearer #{summary_edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        # ticket revenue: 2 * 50.00 * 100 = 10000
        # paid exhibitor revenue: 1200.50 * 100 = 120050
        # pending exhibitor payment is excluded
        expect(data['total_revenue']).to eq(130050)
      end

      it 'handles events with only draft status' do
        draft_event1 = create(:event, status: :draft, visibility: true)
        draft_event2 = create(:event, status: :draft, visibility: true)

        ticket_type = create(:ticket_type, event: draft_event1, price: 40.00)
        create_list(:ticket, 3, event: draft_event1, ticket_type: ticket_type, status: :purchased)

        get '/v1/metrics/summary', params: {}, headers: {
          'Authorization' => "Bearer #{summary_edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['total_events']).to eq(2)
        expect(data['active_events']).to eq(0) # Only counts published
        expect(data['total_tickets']).to eq(3) # Still counts tickets from draft events
      end

      it 'calculates total_locations correctly across multiple events' do
        event1 = create(:event, status: :published, visibility: true)
        event2 = create(:event, status: :published, visibility: true)
        event3 = create(:event, status: :draft, visibility: true)

        create(:event_location, event: event1)
        create(:event_location, event: event1)
        create(:event_location, event: event2)
        create(:event_location, event: event3)

        get '/v1/metrics/summary', params: {}, headers: {
          'Authorization' => "Bearer #{summary_edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        # Each event factory creates 1 location, plus manual ones = 1 + 2 + 1 + 1 + 1 + 1 = 7
        # event1: 1 (auto) + 2 (manual) = 3
        # event2: 1 (auto) + 1 (manual) = 2
        # event3: 1 (auto) + 1 (manual) = 2
        # Total: 7
        expect(data['total_locations']).to eq(7)
      end
    end

    # Additional edge case tests for events_overview
    context 'Edge cases for events_overview' do
      let(:edge_case_user) { create(:user, :org_owner) }
      let(:edge_case_token) { JwtService.generate_tokens(edge_case_user)[:access_token] }

      # Clear existing events to isolate test data
      before do
        Ticket.destroy_all
        TicketType.destroy_all
        EventLocation.destroy_all
        EventAssignment.destroy_all
        Event.destroy_all
      end

      it 'handles events with no tickets' do
        empty_event = create(:event, status: :published, visibility: true)
        create(:event_location, event: empty_event)

        get '/v1/metrics/events_overview', params: {}, headers: {
          'Authorization' => "Bearer #{edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        event_data = data['events'].find { |e| e['id'] == empty_event.id }
        expect(event_data['total_tickets']).to eq(0)
        expect(event_data['scanned_tickets']).to eq(0)
        expect(event_data['unscanned_tickets']).to eq(0)
        expect(event_data['total_revenue']).to eq(0)
      end

      it 'excludes refunded and canceled tickets from calculations' do
        event_with_refunded = create(:event, status: :published, visibility: true)
        ticket_type = create(:ticket_type, event: event_with_refunded, price: 100.00)

        # Active tickets
        create(:ticket, event: event_with_refunded, ticket_type: ticket_type, status: :purchased)
        create(:ticket, event: event_with_refunded, ticket_type: ticket_type, status: :scanned, checked_in: true)

        # Should be excluded
        create(:ticket, event: event_with_refunded, ticket_type: ticket_type, status: :refunded)
        create(:ticket, event: event_with_refunded, ticket_type: ticket_type, status: :canceled)

        get '/v1/metrics/events_overview', params: {}, headers: {
          'Authorization' => "Bearer #{edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        event_data = data['events'].find { |e| e['id'] == event_with_refunded.id }
        expect(event_data['total_tickets']).to eq(2)
        expect(event_data['total_revenue']).to eq(20000) # 2 * 100.00 * 100
      end

      it 'handles tickets with different prices correctly' do
        event = create(:event, status: :published, visibility: true)
        ticket_type_cheap = create(:ticket_type, event: event, price: 25.50)
        ticket_type_expensive = create(:ticket_type, event: event, price: 150.75)

        create_list(:ticket, 3, event: event, ticket_type: ticket_type_cheap, status: :purchased)
        create_list(:ticket, 2, event: event, ticket_type: ticket_type_expensive, status: :purchased)

        get '/v1/metrics/events_overview', params: {}, headers: {
          'Authorization' => "Bearer #{edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        event_data = data['events'].find { |e| e['id'] == event.id }
        expect(event_data['total_tickets']).to eq(5)
        # 3 * 25.50 + 2 * 150.75 = 76.50 + 301.50 = 378.00 * 100 = 37800
        expect(event_data['total_revenue']).to eq(37800)
      end

      it 'includes paid exhibitor registration revenue in event total_revenue' do
        event = create(:event, status: :published, visibility: true)
        ticket_type = create(:ticket_type, event: event, price: 80.00)
        create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :purchased)

        exhibitor = create(:exhibitor, :with_exhibitor_kit, event: event)
        create(
          :exhibitor_registration_payment,
          exhibitor_kit: exhibitor.exhibitor_kit,
          amount: 500,
          status: "paid",
        )

        another_exhibitor = create(:exhibitor, :with_exhibitor_kit, event: event)
        create(
          :exhibitor_registration_payment,
          exhibitor_kit: another_exhibitor.exhibitor_kit,
          amount: 250,
          status: "failed",
        )

        get '/v1/metrics/events_overview', params: {}, headers: {
          'Authorization' => "Bearer #{edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        event_data = data['events'].find { |e| e['id'] == event.id }
        # ticket revenue: 2 * 80.00 * 100 = 16000
        # paid exhibitor revenue: 500 * 100 = 50000
        # failed exhibitor payment is excluded
        expect(event_data['total_revenue']).to eq(66000)
      end

      it 'returns empty array for user with no events' do
        isolated_user = create(:user, :org_owner)
        isolated_token = JwtService.generate_tokens(isolated_user)[:access_token]

        get '/v1/metrics/events_overview', params: {}, headers: {
          'Authorization' => "Bearer #{isolated_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        expect(data['events']).to be_an(Array)
        expect(data['events'].length).to eq(0)
      end

      it 'calculates unscanned tickets correctly' do
        event = create(:event, status: :published, visibility: true)
        ticket_type = create(:ticket_type, event: event, price: 50.00)

        # Create 10 purchased tickets
        create_list(:ticket, 10, event: event, ticket_type: ticket_type, status: :purchased)
        # Create 3 scanned tickets
        create_list(:ticket, 3, event: event, ticket_type: ticket_type, status: :scanned, checked_in: true)
        # Create 2 scanned but unchecked (edge case)
        create_list(:ticket, 2, event: event, ticket_type: ticket_type, status: :scanned, checked_in: false)

        get '/v1/metrics/events_overview', params: {}, headers: {
          'Authorization' => "Bearer #{edge_case_token}"
        }

        expect(response).to have_http_status(:ok)
        data = JSON.parse(response.body)
        event_data = data['events'].find { |e| e['id'] == event.id }
        expect(event_data['total_tickets']).to eq(15) # 10 + 3 + 2
        expect(event_data['scanned_tickets']).to eq(3) # Only checked_in ones
        expect(event_data['unscanned_tickets']).to eq(12) # 10 + 2
      end
    end
  end

  # ===================================================================
  # EXISTING GLOBAL ENDPOINTS (Requires org_owner/organizer)
  # ===================================================================

  path '/v1/metrics/total_tickets' do
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

  path '/v1/metrics/total_scanned_tickets' do
    get 'Get total scanned tickets count across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total scanned tickets retrieved successfully' do
        schema type: :object,
               properties: {
                 totalScannedTickets: { type: :integer, description: 'Total number of scanned tickets across all events' }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['totalScannedTickets']).to eq(3) # 2 + 1 = 3 scanned tickets
        end
      end
    end
  end

  path '/v1/metrics/total_unscanned_tickets' do
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

  path '/v1/metrics/total_amount_price' do
    get 'Get total sales amount across all accessible events' do
      tags 'Global Analytics'
      produces 'application/json'
      parameter name: 'Authorization', in: :header, type: :string, description: 'Bearer token'

      response '200', 'Total sales amount retrieved successfully' do
        schema type: :object,
               properties: {
                 totalAmountPrice: { type: :integer, description: 'Total sales amount in cents across all events' }
               }

        let(:Authorization) { "Bearer #{organizer_token}" }

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

  # =========================================================================
  # Email Verification Requirement Tests
  # =========================================================================

  describe 'Email Verification Enforcement for Analytics' do
    let(:unverified_user) { create(:user, :unverified) }
    let(:unverified_token) { JwtService.generate_tokens(unverified_user)[:access_token] }

    context 'when unverified user tries to access analytics' do
      it 'returns 403 Forbidden for events_overview' do
        get '/v1/metrics/events_overview', headers: { 'Authorization' => "Bearer #{unverified_token}" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Email verification required')
      end

      it 'returns 403 Forbidden for summary' do
        get '/v1/metrics/summary', headers: { 'Authorization' => "Bearer #{unverified_token}" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Email verification required')
      end
    end
  end
end

RSpec.describe 'Vendor analytics after kit cancellation', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }

  it 'counts only exhibitors with an active or paid kit' do
    create(:merchant, event: event)
    create(:exhibitor, :with_exhibitor_kit, event: event)
    stale_exhibitor = create(:exhibitor, :with_exhibitor_kit, event: event)
    stale_exhibitor.exhibitor_kits.update_all(booking_status: ExhibitorKit.booking_statuses[:cancelled])

    get '/v1/metrics/summary', headers: { 'Authorization' => "Bearer #{jwt_token(org_owner)}" }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['total_vendors']).to eq(2)
  end
end
