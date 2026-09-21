# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserActivityRecorder do
  let(:user) { create(:user) }

  describe '.record' do
    let(:request) do
      double(
        'Request',
        path: '/v1/scan/TICKET-999/check_in',
        request_method: 'PATCH',
        params: ActionController::Parameters.new(controller: 'v1/scan', action: 'check_in', public_id: 'TICKET-999', password: 'secretpassword'),
        remote_ip: '192.168.1.1',
        user_agent: 'Mozilla/5.0 Test Agent'
      )
    end

    it 'records the activity with friendly name and sanitized params' do
      expect {
        described_class.record(user, request)
      }.to change(UserActivity, :count).by(1)

      activity = UserActivity.last
      expect(activity.user).to eq(user)
      expect(activity.category).to eq('ticketing')
      expect(activity.action_name).to eq('Checked in Attendee / Scanned Ticket')
      expect(activity.http_method).to eq('PATCH')
      expect(activity.path).to eq('/v1/scan/TICKET-999/check_in')
      expect(activity.details).to include('public_id' => 'TICKET-999')
      expect(activity.details).not_to have_key('password')
      expect(activity.ip_address).to eq('192.168.1.1')
      expect(activity.event_id).to be_nil
    end

    it 'records an event-scoped request with its event_id' do
      request.params[:event_id] = '42'

      described_class.record(user, request)

      expect(UserActivity.last.event_id).to eq(42)
    end

    {
      ['v1/visitors', 'create'] => ['visitors', 'Created Visitor'],
      ['v1/event_staff', 'create'] => ['event_setup', 'Assigned Event Staff'],
      ['v1/event_sponsorship_payments', 'create'] => ['payments', 'Recorded Sponsorship Payment'],
      ['v1/event_sponsorships', 'create'] => ['sponsorships', 'Created Sponsorship'],
      ['v1/lucky_draw/gifts', 'create'] => ['lucky_draw', 'Added Gift/Prize'],
      ['v1/wishes', 'approve'] => ['wish_wall', 'Approved Wish'],
      ['v1/certificates', 'send_batch'] => ['certificates', 'Requested Certificate Batch'],
      ['v1/seating_groups', 'create'] => ['seating', 'Created Seating Group']
    }.each do |(controller, action), (category, action_name)|
      it "records #{controller}##{action} with the event" do
        scoped_request = double(
          'Request',
          path: "/#{controller}/#{action}",
          request_method: 'POST',
          params: ActionController::Parameters.new(controller: controller, action: action, event_id: '42'),
          remote_ip: '127.0.0.1',
          user_agent: 'Test'
        )

        described_class.record(user, scoped_request)
        expect(UserActivity.last).to have_attributes(category: category, action_name: action_name, event_id: 42)
      end
    end

    describe 'ticket update categorization' do
      let(:ticket) { create(:ticket) }

      def update_request(ticket_params)
        double(
          'Request',
          path: "/v1/tickets/#{ticket.public_id}",
          request_method: 'PATCH',
          params: ActionController::Parameters.new(
            controller: 'v1/tickets', action: 'update', id: ticket.public_id, ticket: ticket_params
          ),
          remote_ip: '127.0.0.1',
          user_agent: 'Test'
        )
      end

      it 'labels a name-only edit as a generic update, even when ticket_type_id is resubmitted unchanged' do
        described_class.record(user, update_request(
          attendee_name: 'New Name', ticket_type_id: ticket.ticket_type_id
        ))

        expect(UserActivity.last.action_name).to eq('Updated Attendee Ticket Details')
      end

      it 'labels it as a ticket type change only when the value actually differs' do
        other_type = create(:ticket_type, event: ticket.event)

        described_class.record(user, update_request(ticket_type_id: other_type.id))

        expect(UserActivity.last.action_name).to eq('Changed Ticket Type')
      end

      it 'labels it as a payment status change only when the value actually differs' do
        described_class.record(user, update_request(payment_status: 'paid'))

        expect(UserActivity.last.action_name).to eq('Changed Payment Status')
      end

      it 'stores attendee details with the ticket resource reference' do
        ticket.update!(attendee_name: 'Harlan Wiggins', attendee_email: 'harlan@example.com')

        described_class.record(user, update_request(attendee_name: 'Harlan Wiggins Jr.'))

        resource = UserActivity.last.details.fetch('resource')
        expect(resource).to include(
          'type' => 'Ticket',
          'id' => ticket.public_id,
          'attendee' => {
            'name' => 'Harlan Wiggins',
            'email' => 'harlan@example.com'
          }
        )
      end
    end

    describe 'event update categorization' do
      let(:event) { create(:event, status: :draft) }

      def event_update_request(event_params)
        double(
          'Request',
          path: "/v1/events/#{event.id}",
          request_method: 'PATCH',
          params: ActionController::Parameters.new(
            controller: 'v1/events', action: 'update', id: event.id.to_s, event: event_params
          ),
          remote_ip: '127.0.0.1',
          user_agent: 'Test'
        )
      end

      it 'labels a title-only edit as a generic update, even when status is resubmitted unchanged' do
        described_class.record(user, event_update_request(title: 'New Title', status: 'draft'))

        expect(UserActivity.last.action_name).to eq('Updated Event Settings')
      end

      it 'labels it as a lifecycle transition only when status actually changes' do
        described_class.record(user, event_update_request(status: 'published'))

        expect(UserActivity.last.action_name).to eq('Published Event')
      end
    end

    it 'leaves account-level API key activity unscoped' do
      key_request = double(
        'Request', path: '/v1/api_keys', request_method: 'POST',
        params: ActionController::Parameters.new(controller: 'v1/api_keys', action: 'create'),
        remote_ip: '127.0.0.1', user_agent: 'Test'
      )

      described_class.record(user, key_request)
      expect(UserActivity.last).to have_attributes(category: 'api_keys', action_name: 'Created API Key', event_id: nil)
    end

    it 'ignores internal paths like /up, /health, /superadmin/' do
      ignored_request = double(
        'Request',
        path: '/v1/superadmin/system_activity',
        request_method: 'GET',
        params: ActionController::Parameters.new(controller: 'v1/superadmin/system_activity', action: 'index'),
        remote_ip: '127.0.0.1',
        user_agent: 'Test'
      )

      expect {
        described_class.record(user, ignored_request)
      }.not_to change(UserActivity, :count)
    end

    it 'throttles duplicate consecutive GET requests within 10 seconds' do
      get_request = double(
        'Request',
        path: '/v1/events/1/tickets',
        request_method: 'GET',
        params: ActionController::Parameters.new(controller: 'v1/tickets', action: 'index', event_id: '1'),
        remote_ip: '127.0.0.1',
        user_agent: 'Test'
      )

      # First GET recorded
      expect {
        described_class.record(user, get_request)
      }.to change(UserActivity, :count).by(1)

      # Immediate second GET throttled
      expect {
        described_class.record(user, get_request)
      }.not_to change(UserActivity, :count)
    end

    it 'excludes superadmin actions by default' do
      superadmin = create(:user, email: 's@s.com')
      superadmin_request = double(
        'Request',
        path: '/v1/events/1',
        request_method: 'PATCH',
        params: ActionController::Parameters.new(controller: 'v1/events', action: 'update'),
        remote_ip: '127.0.0.1',
        user_agent: 'Test',
        headers: {}
      )

      expect {
        described_class.record(superadmin, superadmin_request)
      }.not_to change(UserActivity, :count)
    end

    it 'records superadmin actions when explicitly chosen via header or param' do
      superadmin = create(:user, email: 's@s.com')
      chosen_request = double(
        'Request',
        path: '/v1/events/1',
        request_method: 'PATCH',
        params: ActionController::Parameters.new(controller: 'v1/events', action: 'update', log_superadmin_activity: 'true'),
        remote_ip: '127.0.0.1',
        user_agent: 'Test',
        headers: {}
      )

      expect {
        described_class.record(superadmin, chosen_request)
      }.to change(UserActivity, :count).by(1)
    end
  end


  describe '.resolve_friendly_action' do
    {
      ['PATCH', 'v1/tickets', 'restore'] => ['ticketing', 'Restored Ticket'],
      ['POST', 'v1/ticket_exports', 'create'] => ['ticketing', 'Exported Tickets'],
      ['POST', 'v1/ticket_applications', 'approve'] => ['ticketing', 'Reviewed Application'],
      ['PATCH', 'v1/ticket_applications', 'approve_rsvp'] => ['ticketing', 'Updated RSVP Status'],
      ['POST', 'v1/visitors', 'create'] => ['visitors', 'Created Visitor'],
      ['PATCH', 'v1/visitors', 'unscan'] => ['visitors', 'Un-scanned Visitor Check-in'],
      ['POST', 'v1/event_staff', 'create'] => ['event_setup', 'Assigned Event Staff'],
      ['POST', 'v1/ticket_types', 'create'] => ['event_setup', 'Created Ticket Type'],
      ['PATCH', 'v1/ticket_type_price_tiers', 'update'] => ['event_setup', 'Updated Price Tier'],
      ['POST', 'v1/seating_groups', 'add_member'] => ['seating', 'Added Group Member'],
      ['POST', 'v1/exhibitor_booths', 'create'] => ['exhibitor', 'Created Booth'],
      ['PATCH', 'v1/exhibitor_booth_prices', 'update'] => ['exhibitor', 'Updated Booth Pricing'],
      ['POST', 'v1/event_sponsorships', 'create'] => ['sponsorships', 'Created Sponsorship'],
      ['POST', 'v1/event_sponsorship_payments', 'create'] => ['payments', 'Recorded Sponsorship Payment'],
      ['POST', 'v1/lucky_draw/gift_winners', 'create'] => ['lucky_draw', 'Drew Winner'],
      ['POST', 'v1/wishes', 'approve'] => ['wish_wall', 'Approved Wish'],
      ['POST', 'v1/certificates', 'send_batch'] => ['certificates', 'Requested Certificate Batch'],
      ['POST', 'v1/groups', 'create'] => ['groups', 'Created Group'],
      ['POST', 'v1/api_keys', 'create'] => ['api_keys', 'Created API Key'],
      ['PATCH', 'v1/payment_details', 'update'] => ['payment_details', 'Updated Payment Details'],
      ['POST', 'v1/authentication', 'revoke_session'] => ['auth', 'Revoked Session']
    }.each do |(method, controller, action), expected|
      it "labels #{controller}##{action}" do
        expect(described_class.resolve_friendly_action(method, controller, action, "/#{controller}/#{action}", {})).to eq(expected)
      end
    end

    it 'labels event lifecycle changes from explicit params, only when status actually differs from the current row' do
      draft_event = create(:event, status: :draft)
      path = "/v1/events/#{draft_event.id}"
      params = { id: draft_event.id.to_s }

      changed_params = params.merge(event: { status: 'published' })
      changes = ActivityChangeTracker.call(controller: 'v1/events', action: 'update', params: changed_params)
      expect(described_class.resolve_friendly_action(
        'PATCH', 'v1/events', 'update', path, changed_params, changes
      )).to eq(['events', 'Published Event'])

      unchanged_params = params.merge(event: { status: 'draft' })
      changes = ActivityChangeTracker.call(controller: 'v1/events', action: 'update', params: unchanged_params)
      expect(described_class.resolve_friendly_action(
        'PATCH', 'v1/events', 'update', path, unchanged_params, changes
      )).to eq(['events', 'Updated Event Settings'])

      expect(described_class.resolve_friendly_action('PATCH', 'v1/events', 'update', path, params))
        .to eq(['events', 'Updated Event Settings'])
    end

    it 'maps business matching reschedule' do
      cat, action = described_class.resolve_friendly_action('POST', 'v1/business_matching/bookings', 'reschedule', '/v1/business_matching/bookings/1/reschedule', {})
      expect(cat).to eq('business_matching')
      expect(action).to eq('Rescheduled Matchmaking Appointment')
    end

    it 'maps voucher redemptions' do
      cat, action = described_class.resolve_friendly_action('POST', 'v1/voucher_redemptions', 'create', '/v1/voucher_redemptions', {})
      expect(cat).to eq('vouchers')
      expect(action).to eq('Redeemed Attendee Voucher')
    end

    it 'maps lucky draw execution' do
      cat, action = described_class.resolve_friendly_action('POST', 'v1/lucky_draw/lucky_draw_sessions', 'create', '/v1/lucky_draw/sessions', {})
      expect(cat).to eq('lucky_draw')
      expect(action).to eq('Created Lucky Draw Session')
    end

    it 'maps table seating assignments' do
      cat, action = described_class.resolve_friendly_action('POST', 'v1/table_assignments', 'create', '/v1/plans/1/assignments', {})
      expect(cat).to eq('seating')
      expect(action).to eq('Assigned Table')
    end
  end
end
