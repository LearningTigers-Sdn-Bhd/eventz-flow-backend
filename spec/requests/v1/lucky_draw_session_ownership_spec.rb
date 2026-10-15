require 'rails_helper'

# Focused check for the lucky-draw session ownership scoping added on top of
# exhibitor access: exhibitors must only see/manage sessions they created
# themselves, never organizer/admin-owned sessions for the same event.
RSpec.describe 'V1::LuckyDraw session ownership', type: :request do
  let(:event) { create(:event) }
  let(:exhibitor) { create(:user, :exhibitor) }
  let(:org_owner) { create(:user, :org_owner) }

  before do
    create(:exhibitor, event: event, vendor: exhibitor)
  end

  def auth_header(user)
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  end

  it 'excludes organizer-created sessions from the exhibitor session list' do
    organizer_session = create(:lucky_draw_session, event: event, created_by: org_owner)
    own_session = create(:lucky_draw_session, event: event, created_by: exhibitor)

    get "/v1/events/#{event.id}/lucky_draw/sessions", headers: auth_header(exhibitor)

    expect(response).to have_http_status(:ok)
    ids = JSON.parse(response.body)['data'].map { |s| s['id'] }
    expect(ids).to include(own_session.id)
    expect(ids).not_to include(organizer_session.id)
  end

  it 'denies an exhibitor viewing an organizer-owned session directly' do
    organizer_session = create(:lucky_draw_session, event: event, created_by: org_owner)

    get "/v1/events/#{event.id}/lucky_draw/sessions/#{organizer_session.id}", headers: auth_header(exhibitor)

    expect(response).to have_http_status(:forbidden)
  end

  it 'denies an exhibitor adding a gift to an organizer-owned session' do
    organizer_session = create(:lucky_draw_session, event: event, created_by: org_owner)

    post "/v1/events/#{event.id}/lucky_draw/sessions/#{organizer_session.id}/gifts",
         params: { name: 'Sneaky Prize', winner_counts: 1 },
         headers: auth_header(exhibitor)

    expect(response).to have_http_status(:forbidden)
  end

  it 'allows an exhibitor to create, view, and add a gift to their own session' do
    post "/v1/events/#{event.id}/lucky_draw/sessions",
         params: { title: 'My Booth Draw', draw_styles: { style: 'wheel', theme: 'wireframe' } },
         headers: auth_header(exhibitor)
    expect(response).to have_http_status(:created)
    session_id = JSON.parse(response.body).dig('data', 'id')

    get "/v1/events/#{event.id}/lucky_draw/sessions/#{session_id}", headers: auth_header(exhibitor)
    expect(response).to have_http_status(:ok)

    post "/v1/events/#{event.id}/lucky_draw/sessions/#{session_id}/gifts",
         params: { name: 'My Prize', winner_counts: 1 },
         headers: auth_header(exhibitor)
    expect(response).to have_http_status(:created)
  end
end
