require 'rails_helper'

RSpec.describe 'V1::Public::Rsvp', type: :request do
  let(:event) { create(:event, status: :published, use_wedding: true, extra_guest_limit: 5) }
  let!(:visitor) { create(:visitor, event: event, rsvp_status: initial_rsvp_status) }
  let(:initial_rsvp_status) { :pending }

  describe 'POST /v1/public/events/:slug/rsvp/:public_id/respond' do
    it 'accepts an attending RSVP without companions' do
      post "/v1/public/events/#{event.slug}/rsvp/#{visitor.public_id}/respond",
           params: {
             rsvp_status: 'attending',
             companions: []
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json['visitor']['rsvp_status']).to eq('attending')
      expect(json['visitor']['companions']).to eq([])
      expect(visitor.reload.rsvp_status).to eq('attending')
    end

    context 'when the invitee still has a legacy nil RSVP status' do
      let(:initial_rsvp_status) { nil }

      it 'still returns success after updating the RSVP' do
        post "/v1/public/events/#{event.slug}/rsvp/#{visitor.public_id}/respond",
             params: {
               rsvp_status: 'attending',
               companions: []
             },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(json['visitor']['rsvp_status']).to eq('attending')
        expect(visitor.reload.rsvp_status).to eq('attending')
      end
    end

    it 'copies the primary invitee wedding side to RSVP-added companions' do
      visitor.update!(custom_fields_data: { 'wedding_side' => 'bride' })

      post "/v1/public/events/#{event.slug}/rsvp/#{visitor.public_id}/respond",
           params: {
             rsvp_status: 'attending',
             companions: [
               {
                 full_name: 'Guest One',
                 phone: '',
                 email: ''
               }
             ]
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(visitor.reload.companions.count).to eq(1)
      expect(visitor.companions.first.custom_fields_data).to include('wedding_side' => 'bride')
    end

    it 'replaces existing companions when re-submitting without guests' do
      create(:visitor, event: event, added_by: visitor, rsvp_status: :attending)

      post "/v1/public/events/#{event.slug}/rsvp/#{visitor.public_id}/respond",
           params: {
             rsvp_status: 'attending',
             companions: []
           },
           as: :json

      expect(response).to have_http_status(:ok)
      expect(json['visitor']['companions']).to eq([])
      expect(visitor.reload.companions).to be_empty
    end

    it 'rejects requests above the extra guest limit' do
      post "/v1/public/events/#{event.slug}/rsvp/#{visitor.public_id}/respond",
           params: {
             rsvp_status: 'attending',
             companions: Array.new(6) do |index|
               {
                 full_name: "Guest #{index + 1}",
                 phone: '',
                 email: ''
               }
             end
           },
           as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json['error']).to eq('You can bring a maximum of 5 additional guests')
      expect(visitor.reload.rsvp_status).to eq(initial_rsvp_status&.to_s)
    end

    context 'when extra guest limit is unlimited' do
      let(:event) { create(:event, status: :published, use_wedding: true, extra_guest_limit: nil) }

      it 'accepts more companions than the former default cap' do
        post "/v1/public/events/#{event.slug}/rsvp/#{visitor.public_id}/respond",
             params: {
               rsvp_status: 'attending',
               companions: Array.new(6) do |index|
                 {
                   full_name: "Guest #{index + 1}",
                   phone: '',
                   email: ''
                 }
               end
             },
             as: :json

        expect(response).to have_http_status(:ok)
        expect(json['visitor']['companions'].size).to eq(6)
        expect(visitor.reload.companions.size).to eq(6)
      end
    end
  end
end
