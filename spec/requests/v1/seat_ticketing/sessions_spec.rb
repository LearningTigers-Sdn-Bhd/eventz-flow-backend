require 'rails_helper'

RSpec.describe 'V1::SeatTicketing::Sessions', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:event_admin) { create(:user) }
  let(:member) { create(:user, :member) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer)[:access_token] }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member)[:access_token] }

  let(:event) { create(:event, use_seat_ticketing: true) }
  let!(:event_assignment) { create(:event_assignment, event: event, user: event_admin, role: :event_admin) }
  
  let(:session_attr) { attributes_for(:event_seat_session, event_id: event.id) }
  let!(:seat_session) { create(:event_seat_session, event: event) }

  describe 'GET /v1/seat_ticketing/sessions' do
    context 'as authorized user' do
      it 'returns sessions for the event' do
        get '/v1/seat_ticketing/sessions', params: { event_id: event.id }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body).size).to eq(1)
      end
    end

    context 'as unauthorized user' do
      it 'returns empty list or forbidden' do
         # Policy scope returns none
        get '/v1/seat_ticketing/sessions', params: { event_id: event.id }, headers: { 'Authorization' => "Bearer #{member_token}" }
        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to be_empty
      end
    end
  end

  describe 'POST /v1/seat_ticketing/sessions' do
    context 'when authorized' do
      it 'creates a session' do
        post '/v1/seat_ticketing/sessions', params: { session: session_attr }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:created)
      end
    end

    context 'when unauthorized (member)' do
      it 'returns forbidden' do
        post '/v1/seat_ticketing/sessions', params: { session: session_attr }, headers: { 'Authorization' => "Bearer #{member_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when event seat ticketing is disabled' do
      let(:disabled_event) { create(:event, use_seat_ticketing: false) }
      let(:disabled_attr) { attributes_for(:event_seat_session, event_id: disabled_event.id) }
      let!(:admin_assignment) { create(:event_assignment, event: disabled_event, user: event_admin, role: :event_admin) }

      it 'returns forbidden' do
        post '/v1/seat_ticketing/sessions', params: { session: disabled_attr }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'PUT /v1/seat_ticketing/sessions/:id' do
    it 'updates the session' do
      put "/v1/seat_ticketing/sessions/#{seat_session.id}", params: { session: { name: 'Updated Name' } }, headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:ok)
      expect(seat_session.reload.name).to eq('Updated Name')
    end
  end

  describe 'DELETE /v1/seat_ticketing/sessions/:id' do
    it 'archives the session (soft delete)' do
      delete "/v1/seat_ticketing/sessions/#{seat_session.id}", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:no_content)
      expect(seat_session.reload.deleted_at).not_to be_nil
    end
  end

  describe 'DELETE /v1/seat_ticketing/sessions/:id/force_delete' do
    it 'deletes the session' do
      delete "/v1/seat_ticketing/sessions/#{seat_session.id}/force_delete", headers: { 'Authorization' => "Bearer #{event_admin_token}" }
      expect(response).to have_http_status(:no_content)
      expect(EventSeatSession.find_by(id: seat_session.id)).to be_nil
    end
  end

  describe 'GET /v1/seat_ticketing/sessions/:id/archive' do
     # Route is defined as: delete :archive in some places? No, check controller
     # Controller: def archive ... @session.archive ... head :no_content
     # Route: In routes.rb: resources :sessions do member do delete :force_delete; patch :restore; end; end
     # Wait, I didn't add :archive route in routes.rb! I only added force_delete and restore.
     # Controller has `archive` method but routes.rb has `resources :sessions`. Rails resources includes DELETE which maps to destroy action.
     # But existing `Event` controller has `delete :archive`? No, existing event controller uses destroy to archive.
     # Let's check my SessionsController code. 
     # `def archive`... `def force_delete`.
     # Standard `destroy` usually maps to DELETE /sessions/:id.
     # In my `SessionsController`, I didn't define `destroy` method! I defined `archive` method but not mapped?
     # Wait, `resources :sessions` maps DELETE /id to `destroy` action.
     # I should rename `archive` to `destroy` in controller to match `resources` default, OR add route.
     # Let me check `SessionsController` content again.
  end
end
