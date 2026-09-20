# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::Superadmin::SystemActivity', type: :request do
  let(:superadmin) { create(:user, email: 's@s.com', role: :org_owner) }
  let(:normal_user) { create(:user, email: 'user@example.com', role: :organizer) }

  def auth_header(user)
    tokens = JwtService.generate_tokens(user)
    { 'Authorization' => "Bearer #{tokens[:access_token]}" }
  end

  describe 'GET /v1/superadmin/system_activity' do
    context 'when user is not s@s.com' do
      it 'returns 403 forbidden' do
        get '/v1/superadmin/system_activity', headers: auth_header(normal_user)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'returns 401 unauthorized' do
        get '/v1/superadmin/system_activity'
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated as s@s.com' do
      let!(:user_activity) do
        UserActivity.create!(
          user: normal_user,
          category: 'business_matching',
          action_name: 'Rescheduled Matchmaking Appointment',
          http_method: 'POST',
          path: '/v1/business_matching/bookings/1/reschedule',
          created_at: 1.minute.ago
        )
      end

      it 'returns critical status when another user is active within 5 minutes' do
        get '/v1/superadmin/system_activity', headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['success']).to eq(true)
        expect(json['deployment_status']['status']).to eq('critical')
        expect(json['deployment_status']['safe_to_deploy']).to eq(false)
        expect(json['audit_logs']['records'].first['action_name']).to eq('Rescheduled Matchmaking Appointment')
      end

      it 'returns warning status when another user was active 8 minutes ago' do
        user_activity.update!(created_at: 8.minutes.ago)
        get '/v1/superadmin/system_activity', headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['deployment_status']['status']).to eq('warning')
        expect(json['deployment_status']['safe_to_deploy']).to eq(false)
      end

      it 'returns safe status when only superadmin is active' do
        user_activity.destroy!
        get '/v1/superadmin/system_activity', headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        expect(json['deployment_status']['status']).to eq('safe')
        expect(json['deployment_status']['safe_to_deploy']).to eq(true)
      end

      it 'filters audit logs by category' do
        UserActivity.create!(
          user: normal_user,
          category: 'ticketing',
          action_name: 'Checked in Attendee / Scanned Ticket',
          http_method: 'PATCH',
          path: '/v1/scan/TICKET-123/check_in',
          created_at: 2.minutes.ago
        )

        get '/v1/superadmin/system_activity', params: { category: 'ticketing' }, headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        records = json['audit_logs']['records']
        expect(records.all? { |r| r['category'] == 'ticketing' }).to eq(true)
        expect(records.first['action_name']).to eq('Checked in Attendee / Scanned Ticket')
      end

      it 'excludes superadmin actions and active users by default' do
        UserActivity.create!(
          user: superadmin,
          category: 'events',
          action_name: 'Created New Event',
          http_method: 'POST',
          path: '/v1/events',
          created_at: 1.minute.ago
        )

        get '/v1/superadmin/system_activity', headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        records = json['audit_logs']['records']
        expect(records.none? { |r| r['user']['email'] == 's@s.com' }).to eq(true)

        active_users = json['active_users']
        expect(active_users.none? { |u| u['email'] == 's@s.com' }).to eq(true)
      end

      it 'searches audit logs by action name or user identity' do
        UserActivity.create!(
          user: normal_user,
          category: 'ticketing',
          action_name: 'Checked in Attendee / Scanned Ticket',
          http_method: 'PATCH',
          path: '/v1/scan/TICKET-123/check_in',
          created_at: 2.minutes.ago
        )

        get '/v1/superadmin/system_activity', params: { q: 'Rescheduled' }, headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        records = json['audit_logs']['records']
        expect(records.map { |r| r['action_name'] }).to eq(['Rescheduled Matchmaking Appointment'])
      end

      it 'filters audit logs by an explicit date range' do
        user_activity.update!(created_at: 10.days.ago)
        UserActivity.create!(
          user: normal_user,
          category: 'ticketing',
          action_name: 'Checked in Attendee / Scanned Ticket',
          http_method: 'PATCH',
          path: '/v1/scan/TICKET-123/check_in',
          created_at: 40.days.ago
        )

        get '/v1/superadmin/system_activity',
            params: { from_date: 15.days.ago.to_date.to_s, to_date: 5.days.ago.to_date.to_s },
            headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        records = json['audit_logs']['records']
        expect(records.map { |r| r['action_name'] }).to eq(['Rescheduled Matchmaking Appointment'])
      end

      it 'flags a burst of repeated same-user, same-action entries as unusual' do
        base = Time.current
        burst_ids = Array.new(10) do |i|
          UserActivity.create!(
            user: normal_user,
            category: 'ticketing',
            action_name: 'Archived Ticket',
            http_method: 'DELETE',
            path: '/v1/tickets/1',
            created_at: base + i.seconds
          ).id
        end

        get '/v1/superadmin/system_activity', headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        records = JSON.parse(response.body)['audit_logs']['records'].index_by { |r| r['id'] }
        burst_ids.each { |id| expect(records[id]['unusual']).to eq(true) }
        expect(records[user_activity.id]['unusual']).to eq(false)
      end

      it 'includes superadmin actions and active users when include_superadmin=true' do
        UserActivity.create!(
          user: superadmin,
          category: 'events',
          action_name: 'Created New Event',
          http_method: 'POST',
          path: '/v1/events',
          created_at: 1.minute.ago
        )

        get '/v1/superadmin/system_activity', params: { include_superadmin: 'true' }, headers: auth_header(superadmin)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)

        records = json['audit_logs']['records']
        expect(records.any? { |r| r['user']['email'] == 's@s.com' }).to eq(true)

        active_users = json['active_users']
        expect(active_users.any? { |u| u['email'] == 's@s.com' }).to eq(true)
      end
    end
  end
end


