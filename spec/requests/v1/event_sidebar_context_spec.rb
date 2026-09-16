require 'rails_helper'

RSpec.describe 'V1 event sidebar context', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event_admin) { create(:user, :member) }
  let(:event) do
    create(
      :event,
      title: 'Sidebar Event',
      status: :published,
      use_ticket: true,
      use_exhibitor_kit: true,
      use_business_matching: true
    )
  end

  before do
    create(:event_assignment, event: event, user: event_admin, role: :event_admin)
  end

  it 'returns lightweight event navigation data and current-user permissions' do
    get "/v1/events/#{event.id}/sidebar_context", headers: auth_headers(event_admin)

    expect(response).to have_http_status(:ok)

    payload = JSON.parse(response.body)
    expect(payload['currentEvent']).to include(
      'id' => event.id,
      'title' => 'Sidebar Event',
      'status' => 'published',
      'use_ticket' => true,
      'use_exhibitor_kit' => true,
      'use_business_matching' => true
    )
    expect(payload['currentEvent']).not_to include('description', 'event_email_setting', 'wish_wall_setting')
    expect(payload['events']).to contain_exactly(payload['currentEvent'])
    expect(payload['permissions']).to include(
      'isEventAdmin' => true,
      'isEventTeamMember' => false,
      'isEventVendor' => false,
      'canManageEvent' => true,
      'canViewAnalytics' => true
    )
  end

  it 'does not expose context for an event the user cannot view' do
    private_event = create(:event, published: false, visibility: false)

    get "/v1/events/#{private_event.id}/sidebar_context", headers: auth_headers(event_admin)

    expect(response).to have_http_status(:forbidden)
  end

  it 'returns all events visible to an organization owner without full event fields' do
    event

    get "/v1/events/#{event.id}/sidebar_context", headers: auth_headers(org_owner)

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body)
    expect(payload['events'].map { |item| item['id'] }).to include(event.id)
    expect(payload['events']).to all(
      satisfy { |item| (%w[description logo_url poster_url wish_wall_setting] & item.keys).empty? }
    )
    expect(payload['permissions']).to include(
      'isOrgOwner' => true,
      'canManageEvent' => true,
      'canManageEventStaff' => true
    )
  end
end
