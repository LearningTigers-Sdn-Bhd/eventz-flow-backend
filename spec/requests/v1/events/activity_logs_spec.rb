# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Event activity logs', type: :request do
  let(:event) { create(:event) }
  let(:other_event) { create(:event) }
  let(:staff) { create(:user, role: :member) }
  let(:owner) { create(:user, role: :org_owner, email: 's@s.com') }
  let(:outsider) { create(:user, role: :member) }
  let(:path) { "/v1/events/#{event.id}/activity_logs" }

  before do
    create(:event_assignment, event: event, user: staff, role: :event_team_member)
    create(:event_assignment, event: event, user: owner, role: :event_admin)
  end

  def headers_for(user)
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  end

  def activity(user:, event_id:, category: 'ticketing', created_at: Time.current)
    UserActivity.create!(user: user, event_id: event_id, category: category,
                         action_name: 'Archived Ticket', http_method: 'DELETE',
                         path: '/v1/tickets/1', created_at: created_at)
  end

  it 'shows only recent activity for the event, excluding owner actions' do
    visible = activity(user: staff, event_id: event.id)
    activity(user: owner, event_id: event.id)
    activity(user: staff, event_id: other_event.id)
    activity(user: staff, event_id: event.id, created_at: 91.days.ago)

    get path, headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }).to eq([visible.id])
  end

  it 'excludes GET/browsing noise from the event activity trail' do
    mutation = activity(user: staff, event_id: event.id)
    UserActivity.create!(user: staff, event_id: event.id, category: 'ticketing',
                         action_name: 'Browsing Tickets / Attendees', http_method: 'GET',
                         path: '/v1/events/1/tickets')

    get path, headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }).to eq([mutation.id])
  end

  it 'filters by category and paginates' do
    activity(user: staff, event_id: event.id, category: 'events')
    activity(user: staff, event_id: event.id, category: 'events')
    activity(user: staff, event_id: event.id, category: 'ticketing')

    get path, params: { category: 'events', page: 2, per_page: 1 }, headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('audit_logs', 'records').size).to eq(1)
    expect(response.parsed_body.dig('audit_logs', 'meta', 'total_count')).to eq(2)
  end

  it 'adds attendee details to existing ticket resource references' do
    ticket = create(:ticket, event: event, attendee_name: 'Harlan Wiggins', attendee_email: 'harlan@example.com')
    log = activity(user: staff, event_id: event.id)
    log.update!(details: { 'resource' => { 'type' => 'Ticket', 'id' => ticket.public_id } })

    get path, headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
    resource = response.parsed_body.dig('audit_logs', 'records', 0, 'details', 'resource')
    expect(resource).to include(
      'id' => ticket.public_id,
      'attendee' => {
        'name' => 'Harlan Wiggins',
        'email' => 'harlan@example.com'
      }
    )
  end

  it 'keeps account-level categories in the owner-only tier' do
    activity(user: staff, event_id: event.id, category: 'api_keys')
    activity(user: staff, event_id: event.id, category: 'groups')

    get path, headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('audit_logs', 'records')).to be_empty
  end

  it 'forbids an unassigned user' do
    get path, headers: headers_for(outsider)
    expect(response).to have_http_status(:forbidden)
  end

  it 'lets the org owner view the event activity log, including their own actions' do
    staff_action = activity(user: staff, event_id: event.id)
    owner_action = activity(user: owner, event_id: event.id)

    get path, headers: headers_for(owner)

    expect(response).to have_http_status(:ok)
    ids = response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }
    expect(ids).to contain_exactly(staff_action.id, owner_action.id)
  end

  it 'filters by user_id' do
    other_staff = create(:user, role: :member)
    create(:event_assignment, event: event, user: other_staff, role: :event_team_member)
    mine = activity(user: staff, event_id: event.id)
    activity(user: other_staff, event_id: event.id)

    get path, params: { user_id: staff.id }, headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }).to eq([mine.id])
  end

  it 'filters by result' do
    ok = activity(user: staff, event_id: event.id)
    failed = UserActivity.create!(user: staff, event_id: event.id, category: 'ticketing',
                                  action_name: 'Updated Ticket Type', http_method: 'PATCH',
                                  path: '/v1/tickets/1', result: 'failed', error_message: 'Not found')

    get path, params: { result: 'failed' }, headers: headers_for(staff)
    expect(response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }).to eq([failed.id])

    get path, params: { result: 'success' }, headers: headers_for(staff)
    expect(response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }).to eq([ok.id])
  end

  it 'searches by action name or user identity' do
    matched = activity(user: staff, event_id: event.id)
    UserActivity.create!(user: staff, event_id: event.id, category: 'events',
                         action_name: 'Updated Event Settings', http_method: 'PATCH', path: '/v1/events/1')

    get path, params: { q: 'archived' }, headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }).to eq([matched.id])
  end

  it 'records the request outcome on the activity row it created' do
    patch "/v1/events/#{event.id}/ticket_types/999999",
          params: { ticket_type: { name: 'Does not matter' } },
          headers: headers_for(staff)

    expect(response).to have_http_status(:not_found)

    logged = UserActivity.where(user_id: staff.id, event_id: event.id).order(:created_at).last
    expect(logged.result).to eq('failed')
    expect(logged.error_message).to be_present
  end

  it 'filters by an explicit date range, overriding the default 90-day window' do
    in_range = activity(user: staff, event_id: event.id, created_at: 10.days.ago)
    activity(user: staff, event_id: event.id, created_at: 40.days.ago)

    get path,
        params: { from_date: 15.days.ago.to_date.to_s, to_date: 5.days.ago.to_date.to_s },
        headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }).to eq([in_range.id])
  end

  it 'ignores an unparsable date filter instead of erroring' do
    activity(user: staff, event_id: event.id)

    get path, params: { from_date: 'not-a-date' }, headers: headers_for(staff)

    expect(response).to have_http_status(:ok)
  end

  describe 'DELETE /v1/events/:event_id/activity_logs/clear' do
    let(:clear_path) { "/v1/events/#{event.id}/activity_logs/clear" }

    it 'lets the org owner permanently clear the event activity log' do
      activity(user: staff, event_id: event.id)
      activity(user: staff, event_id: other_event.id)

      delete clear_path, headers: headers_for(owner)

      expect(response).to have_http_status(:ok)
      expect(UserActivity.where(event_id: event.id).count).to eq(0)
      expect(UserActivity.where(event_id: other_event.id).count).to eq(1)
    end

    it 'forbids non-owner staff from clearing the log' do
      activity(user: staff, event_id: event.id)

      delete clear_path, headers: headers_for(staff)

      expect(response).to have_http_status(:forbidden)
      expect(UserActivity.where(event_id: event.id).count).to eq(1)
    end
  end

  it 'keeps owner actions visible in the existing superadmin view' do
    owner_action = activity(user: owner, event_id: event.id)

    get '/v1/superadmin/system_activity', params: { include_superadmin: true }, headers: headers_for(owner)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig('audit_logs', 'records').map { |row| row['id'] }).to include(owner_action.id)
  end
end
