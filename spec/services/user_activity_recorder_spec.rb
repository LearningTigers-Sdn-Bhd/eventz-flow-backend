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
      expect(action).to eq('Running Live Lucky Draw')
    end

    it 'maps table seating assignments' do
      cat, action = described_class.resolve_friendly_action('POST', 'v1/table_assignments', 'create', '/v1/plans/1/assignments', {})
      expect(cat).to eq('seating')
      expect(action).to eq('Updated Table Seating / Assigned Seat')
    end
  end
end
