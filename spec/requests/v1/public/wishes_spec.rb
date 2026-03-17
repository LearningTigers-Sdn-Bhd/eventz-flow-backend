require 'rails_helper'

RSpec.describe 'V1::Public::Wishes', type: :request do
  let(:event) { create(:event, status: :published, use_wedding: true) }

  describe 'POST /v1/public/events/:slug/wishes' do
    it 'creates a pending wish' do
      post "/v1/public/events/#{event.slug}/wishes",
           params: { guest_name: 'Mak Long', message: 'Blessings always' },
           as: :json

      expect(response).to have_http_status(:created)
      expect(json['wish']['status']).to eq('pending')
    end

    it 'attaches the visitor when visitor_public_id is valid' do
      visitor = create(:visitor, event: event)

      post "/v1/public/events/#{event.slug}/wishes",
           params: { guest_name: 'Mak Long', message: 'Blessings always', visitor_public_id: visitor.public_id },
           as: :json

      expect(Wish.last.visitor).to eq(visitor)
    end

    it 'returns 422 when message is blank' do
      post "/v1/public/events/#{event.slug}/wishes",
           params: { guest_name: 'Mak Long', message: '' },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 404 for non-wedding events' do
      non_wedding = create(:event, status: :published, use_wedding: false)

      post "/v1/public/events/#{non_wedding.slug}/wishes",
           params: { guest_name: 'Test', message: 'Hello' },
           as: :json

      expect(response).to have_http_status(:not_found)
    end

    it 'auto-approves and broadcasts when the event toggle is enabled and the local filter approves the message' do
      event.update!(auto_approve_wishes: true)

      expect(ActionCable.server).to receive(:broadcast).with(
        "wishes_wall_event_#{event.id}",
        hash_including(type: 'new_wish')
      )

      post "/v1/public/events/#{event.slug}/wishes",
           params: { guest_name: 'Mak Long', message: 'Blessings always' },
           as: :json

      expect(response).to have_http_status(:created)
      expect(json['wish']['status']).to eq('approved')
      expect(Wish.last.approved_at).not_to be_nil
    end

    it 'rejects the wish when the local filter marks the message as unsuitable' do
      event.update!(auto_approve_wishes: true)

      expect(ActionCable.server).not_to receive(:broadcast)

      post "/v1/public/events/#{event.slug}/wishes",
           params: { guest_name: 'Mak Long', message: 'You are bodoh and stupid' },
           as: :json

      expect(response).to have_http_status(:created)
      expect(json['wish']['status']).to eq('rejected')
      expect(Wish.last.approved_at).to be_nil
    end

    it 'marks suspicious promotional wishes as pending review' do
      event.update!(auto_approve_wishes: true)

      expect(ActionCable.server).not_to receive(:broadcast)

      post "/v1/public/events/#{event.slug}/wishes",
           params: { guest_name: 'Mak Long', message: 'Visit https://spam.test now for fast cash' },
           as: :json

      expect(response).to have_http_status(:created)
      expect(json['wish']['status']).to eq('pending')
      expect(Wish.last.approved_at).to be_nil
    end

    it 'does not auto-approve when auto approve is disabled' do
      post "/v1/public/events/#{event.slug}/wishes",
           params: { guest_name: 'Mak Long', message: 'Blessings always' },
           as: :json

      expect(response).to have_http_status(:created)
      expect(json['wish']['status']).to eq('pending')
    end
  end

  describe 'GET /v1/public/events/:slug/wishes' do
    it 'returns only approved wishes for display' do
      create(:wish, :approved, event: event, guest_name: 'Kak Lina')
      create(:wish, event: event)

      get "/v1/public/events/#{event.slug}/wishes", as: :json

      expect(response).to have_http_status(:ok)
      expect(json['wishes'].map { |w| w['guest_name'] }).to eq(['Kak Lina'])
    end

    it 'returns all approved wishes without a six-item cap' do
      7.times do |index|
        create(:wish, :approved, event: event, guest_name: "Guest #{index + 1}", approved_at: index.minutes.ago)
      end

      get "/v1/public/events/#{event.slug}/wishes", as: :json

      expect(response).to have_http_status(:ok)
      expect(json['wishes'].length).to eq(7)
    end
  end
end
