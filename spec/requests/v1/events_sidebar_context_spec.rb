require 'rails_helper'

# Guards the event_assignment_roles_for memoization added to cut redundant
# event_assignments queries out of GET /v1/events/:id/sidebar_context
# (previously queried separately by the show? policy chain and by
# sidebar_permissions).
RSpec.describe 'GET /v1/events/:id/sidebar_context', type: :request do
  let(:event) { create(:event, published: false, visibility: true) }

  it 'returns event admin permissions for an assigned event admin' do
    admin_user = create(:user)
    create(:event_assignment, event: event, user: admin_user, role: :event_admin)

    get "/v1/events/#{event.id}/sidebar_context", headers: auth_headers(admin_user)

    expect(response).to have_http_status(:ok)
    permissions = json_response['permissions']
    expect(permissions['isEventAdmin']).to be true
    expect(permissions['canManageEvent']).to be true
  end

  it 'denies a user with no assignment to a private event' do
    other_user = create(:user)

    get "/v1/events/#{event.id}/sidebar_context", headers: auth_headers(other_user)

    expect(response).to have_http_status(:forbidden)
  end
end
