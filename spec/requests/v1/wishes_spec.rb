require 'rails_helper'

RSpec.describe 'V1::Wishes', type: :request do
  describe 'GET /v1/events/:event_id/wishes' do
    it 'filters wishes by status' do
      user = create(:user)
      wedding_event = create(:event, status: :published, use_wedding: true)
      create(:event_assignment, event: wedding_event, user: user, role: :event_admin)

      create(:wish, event: wedding_event)
      create(:wish, :approved, event: wedding_event)

      get "/v1/events/#{wedding_event.id}/wishes", params: { status: 'pending' }, headers: auth_headers(user)

      expect(response).to have_http_status(:ok)
      expect(json['wishes'].length).to eq(1)
    end

    it 'returns 404 for non-wedding events' do
      user = create(:user)
      non_wedding = create(:event, status: :published, use_wedding: false)
      create(:event_assignment, event: non_wedding, user: user, role: :event_admin)

      get "/v1/events/#{non_wedding.id}/wishes", headers: auth_headers(user)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'PATCH /v1/events/:event_id/wishes/:id/approve' do
    it 'approves and broadcasts a wish' do
      user = create(:user)
      wedding_event = create(:event, status: :published, use_wedding: true)
      create(:event_assignment, event: wedding_event, user: user, role: :event_admin)
      wish = create(:wish, event: wedding_event)

      expect(ActionCable.server).to receive(:broadcast).with(
        "wishes_wall_event_#{wedding_event.id}",
        hash_including(type: 'new_wish')
      )

      patch "/v1/events/#{wedding_event.id}/wishes/#{wish.id}/approve", headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(wish.reload).to be_approved
      expect(wish.approved_at).not_to be_nil
    end
  end

  describe 'PATCH /v1/events/:event_id/wishes/:id/reject' do
    it 'rejects a wish without broadcasting' do
      user = create(:user)
      wedding_event = create(:event, status: :published, use_wedding: true)
      create(:event_assignment, event: wedding_event, user: user, role: :event_admin)
      wish = create(:wish, event: wedding_event)

      expect(ActionCable.server).not_to receive(:broadcast)

      patch "/v1/events/#{wedding_event.id}/wishes/#{wish.id}/reject", headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect(wish.reload).to be_rejected
    end
  end

  describe 'DELETE /v1/events/:event_id/wishes/:id' do
    it 'deletes an approved wish and broadcasts removal' do
      user = create(:user)
      wedding_event = create(:event, status: :published, use_wedding: true)
      create(:event_assignment, event: wedding_event, user: user, role: :event_admin)
      wish = create(:wish, :approved, event: wedding_event)

      expect(ActionCable.server).to receive(:broadcast).with(
        "wishes_wall_event_#{wedding_event.id}",
        hash_including(type: 'remove_wish', wish_id: wish.id)
      )

      delete "/v1/events/#{wedding_event.id}/wishes/#{wish.id}", headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
      expect { wish.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'deletes a pending wish without broadcasting' do
      user = create(:user)
      wedding_event = create(:event, status: :published, use_wedding: true)
      create(:event_assignment, event: wedding_event, user: user, role: :event_admin)
      wish = create(:wish, event: wedding_event)

      expect(ActionCable.server).not_to receive(:broadcast)

      delete "/v1/events/#{wedding_event.id}/wishes/#{wish.id}", headers: auth_headers(user), as: :json

      expect(response).to have_http_status(:ok)
    end
  end
end
