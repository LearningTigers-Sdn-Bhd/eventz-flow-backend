# scan_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Scan', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:member_user) { create(:user, :member) }
  let(:staff_user) { create(:user, :staff_member) }
  let(:other_staff_user) { create(:user, :staff_member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:staff_token) { JwtService.generate_tokens(staff_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }
  let(:other_staff_token) { JwtService.generate_tokens(other_staff_user)[:access_token] }

  # --- Setup Event ---
  let!(:organizer_event) do
    event = create(:event, title: 'Organizer Event', payment_status: :paid)
    EventAssignment.find_or_create_by!(event: event, user: organizer_user, role: :event_admin)
    create(:event_assignment, role: :event_team_member, event: event, user: staff_user)
    event
  end

  # --- Setup Ticket Type ---
  let!(:general_ticket_type) { create(:ticket_type, event: organizer_event, name: 'GA') }

  # --- Setup Tickets ---
  let!(:purchased_ticket) do
    create(:ticket, event: organizer_event, ticket_type: general_ticket_type, status: :purchased, attendee_name: 'Purchased Attendee')
  end

  let!(:checked_in_ticket) do
    ticket = create(:ticket, event: organizer_event, ticket_type: general_ticket_type,
                    checked_in: true, check_in_at: 1.hour.ago, status: :scanned,
                    attendee_name: 'Scanned Attendee', scanned_by: staff_user)
    create(:scan_log, event: organizer_event, scannable: ticket,
                      scanned_at: ticket.check_in_at, scanned_by: staff_user)
    ticket
  end

  # --- Setup Visitors ---
  let!(:unchecked_visitor) do
    create(:visitor, event: organizer_event, full_name: 'New Visitor', email: 'visitor@example.com')
  end

  let!(:checked_in_visitor) do
    visitor = create(:visitor, event: organizer_event, full_name: 'Checked Visitor', email: 'checked@example.com',
                     checked_in: true, check_in_at: 30.minutes.ago, scanned_by: staff_user)
    create(:scan_log, event: organizer_event, scannable: visitor,
                      scanned_at: visitor.check_in_at, scanned_by: staff_user)
    visitor
  end

  # =========================================================================
  # GET /v1/scan/recent_check_ins
  # =========================================================================

  path '/v1/scan/recent_check_ins' do
    get 'Lists recent check-ins scanned by the current user' do
      tags 'Scan'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :event_id, in: :query, type: :integer, required: false,
                description: 'Filter by specific event ID'
      parameter name: :limit, in: :query, type: :integer, required: false,
                description: 'Number of records to return (default: 50, max: 100)'

      response '200', 'Returns recent check-ins scanned by current user' do
        let(:Authorization) { "Bearer #{staff_token}" }

        schema type: :object,
               properties: {
                 check_ins: {
                   type: :array,
                   items: {
                     type: :object,
                     properties: {
                       type: { type: :string, enum: %w[ticket visitor] },
                       scan_id: { type: :string },
                       name: { type: :string },
                       email: { type: :string },
                       event_id: { type: :integer },
                       event_name: { type: :string },
                       checked_in: { type: :boolean },
                       check_in_at: { type: :string },
                       status: { type: :string }
                     }
                   }
                 },
                 total: { type: :integer },
                 limit: { type: :integer }
               }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['check_ins']).to be_an(Array)
          expect(json['total']).to be_a(Integer)
          expect(json['limit']).to eq(50)

          # Should only return check-ins scanned by current user (staff_user)
          json['check_ins'].each do |check_in|
            expect(check_in['scanned_by']['id']).to eq(staff_user.id)
          end
        end
      end

      response '200', 'Returns empty array when user has no check-ins' do
        let(:Authorization) { "Bearer #{other_staff_token}" }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['check_ins']).to eq([])
          expect(json['total']).to eq(0)
        end
      end

      response '200', 'Respects limit parameter' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:limit) { 1 }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['check_ins'].length).to be <= 1
          expect(json['limit']).to eq(1)
        end
      end

      response '200', 'Filters by event_id when provided' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:event_id) { organizer_event.id }

        run_test! do |response|
          json = JSON.parse(response.body)
          json['check_ins'].each do |check_in|
            expect(check_in['event_id']).to eq(organizer_event.id)
          end
        end
      end

      response '403', 'Forbidden when filtering by unauthorized event' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:event_id) { 999999 }

        run_test!
      end

      response '401', 'Unauthorized without token' do
        let(:Authorization) { nil }

        run_test!
      end
    end
  end

  # =========================================================================
  # PATCH /v1/scan/:public_id/check_in
  # =========================================================================

  path '/v1/scan/{public_id}/check_in' do
    parameter name: :public_id, in: :path, type: :string, description: 'Public ID (UUID) of ticket or visitor'

    patch 'Performs unified check-in for ticket or visitor' do
      tags 'Scan'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true

      # --- Ticket Check-in Tests ---

      response '200', 'Ticket check-in successful' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:public_id) { purchased_ticket.public_id }

        schema type: :object,
               properties: {
                 type: { type: :string },
                 public_id: { type: :string },
                 checked_in: { type: :boolean },
                 check_in_at: { type: :string },
                 attendee_name: { type: :string },
                 attendee_email: { type: :string },
                 event: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     title: { type: :string }
                   }
                 },
                 scanned_by: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     full_name: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['type']).to eq('ticket')
          expect(json['checked_in']).to be true
          expect(json['scanned_by']['id']).to eq(staff_user.id)

          purchased_ticket.reload
          expect(purchased_ticket.checked_in).to be true
          expect(purchased_ticket.status).to eq('scanned')
          expect(purchased_ticket.scanned_by_id).to eq(staff_user.id)
        end
      end

      response '422', 'Ticket already checked in' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:public_id) { checked_in_ticket.public_id }

        schema type: :object,
               properties: {
                 error: { type: :string },
                 type: { type: :string },
                 checked_in_at: { type: :string }
               }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['error']).to include('already been checked in')
          expect(json['type']).to eq('ticket')
        end
      end

      # --- Visitor Check-in Tests ---

      response '200', 'Visitor check-in successful' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:public_id) { unchecked_visitor.public_id }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['type']).to eq('visitor')
          expect(json['checked_in']).to be true
          expect(json['scanned_by']['id']).to eq(staff_user.id)

          unchecked_visitor.reload
          expect(unchecked_visitor.checked_in).to be true
          expect(unchecked_visitor.scanned_by_id).to eq(staff_user.id)
        end
      end

      response '422', 'Visitor already checked in' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:public_id) { checked_in_visitor.public_id }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['error']).to include('already been checked in')
          expect(json['type']).to eq('visitor')
        end
      end

      # --- Error Cases ---

      response '404', 'Record not found' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:public_id) { '00000000-0000-0000-0000-000000000000' }

        schema type: :object,
               properties: {
                 error: { type: :string }
               }

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['error']).to include('Record not found')
        end
      end

      response '403', 'Forbidden for unauthorized user' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:public_id) { purchased_ticket.public_id }

        run_test!
      end

      response '401', 'Unauthorized without token' do
        let(:Authorization) { nil }
        let(:public_id) { purchased_ticket.public_id }

        run_test!
      end
    end
  end

  # =========================================================================
  # Additional Unit Tests
  # =========================================================================

  describe 'Recent Check-ins Behavior' do
    context 'when user scans multiple records' do
      before do
        # Create additional check-ins by staff_user
        create(:ticket, event: organizer_event, ticket_type: general_ticket_type,
               checked_in: true, check_in_at: 5.minutes.ago, status: :scanned,
               attendee_name: 'Recent Attendee', scanned_by: staff_user)
      end

      it 'returns check-ins sorted by check_in_at descending' do
        get '/v1/scan/recent_check_ins', headers: { 'Authorization' => "Bearer #{staff_token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        check_in_times = json['check_ins'].map { |c| c['check_in_at'] }
        expect(check_in_times).to eq(check_in_times.sort.reverse)
      end
    end

    context 'when limit exceeds maximum' do
      it 'caps limit at 100' do
        get '/v1/scan/recent_check_ins', params: { limit: 200 },
            headers: { 'Authorization' => "Bearer #{staff_token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['limit']).to eq(100)
      end
    end

    context 'when another staff member has also scanned in this event' do
      before do
        create(:event_assignment, role: :event_team_member, event: organizer_event, user: other_staff_user)
      end

      it "shows only the current user's own scans, not every staff member's" do
        other_ticket = create(:ticket, event: organizer_event, ticket_type: general_ticket_type,
                              checked_in: true, check_in_at: 1.minute.ago, status: :scanned,
                              attendee_name: "Other Staff's Scan", scanned_by: other_staff_user)
        create(:scan_log, event: organizer_event, scannable: other_ticket,
                          scanned_at: other_ticket.check_in_at, scanned_by: other_staff_user)

        get '/v1/scan/recent_check_ins', headers: { 'Authorization' => "Bearer #{staff_token}" }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        names = json['check_ins'].map { |c| c['name'] }
        expect(names).not_to include("Other Staff's Scan")
      end
    end
  end

  describe 'Unified Check-in Behavior' do
    context 'when checking in a ticket' do
      it 'sets status to scanned' do
        patch "/v1/scan/#{purchased_ticket.public_id}/check_in",
              headers: { 'Authorization' => "Bearer #{staff_token}" }

        expect(response).to have_http_status(:ok)
        purchased_ticket.reload
        expect(purchased_ticket.status).to eq('scanned')
      end
    end

    context 'when checking in a visitor' do
      it 'does not affect status field (visitors have no status)' do
        patch "/v1/scan/#{unchecked_visitor.public_id}/check_in",
              headers: { 'Authorization' => "Bearer #{staff_token}" }

        expect(response).to have_http_status(:ok)
        unchecked_visitor.reload
        expect(unchecked_visitor.checked_in).to be true
      end
    end
  end

  # =========================================================================
  # Email Verification Enforcement
  # =========================================================================

  describe 'Email Verification Enforcement' do
    let(:unverified_user) { create(:user, :unverified) }
    let(:unverified_token) { JwtService.generate_tokens(unverified_user)[:access_token] }

    it 'returns 403 for recent_check_ins with unverified email' do
      get '/v1/scan/recent_check_ins', headers: { 'Authorization' => "Bearer #{unverified_token}" }

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Email verification required')
    end

    it 'returns 403 for check_in with unverified email' do
      patch "/v1/scan/#{purchased_ticket.public_id}/check_in",
            headers: { 'Authorization' => "Bearer #{unverified_token}" }

      expect(response).to have_http_status(:forbidden)
      json = JSON.parse(response.body)
      expect(json['message']).to eq('Email verification required')
    end
  end

  describe 'GET /v1/scan/recent_check_ins with multiple scans' do
    let(:event) { create(:event, multiple_scans: true, multiple_scan_mode: :unlimited) }
    let(:staff) { create(:user, :org_owner) }
    let(:early) { create(:ticket, event: event, attendee_name: 'Early Bird') }
    let(:late) { create(:ticket, event: event, attendee_name: 'Late Returner') }

    it 'orders by the most recent scan, not by first arrival' do
      ScanGate.record!(early, by: staff, at: 2.hours.ago)
      ScanGate.record!(late, by: staff, at: 90.minutes.ago)
      # Early Bird re-enters — should now be the most recent entry.
      ScanGate.record!(early, by: staff, at: 10.minutes.ago)

      get '/v1/scan/recent_check_ins', headers: { 'Authorization' => "Bearer #{JwtService.generate_tokens(staff)[:access_token]}" }

      expect(response).to have_http_status(:ok)
      names = JSON.parse(response.body)['check_ins'].map { |r| r['name'] || r['attendee_name'] }
      expect(names.first).to eq('Early Bird')
    end
  end
end
