require 'rails_helper'

RSpec.describe 'V1::EventSponsorshipItems', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  
  let(:event) { create(:event) }
  let(:sponsorship) { create(:event_sponsorship, event: event) }
  
  describe 'POST /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_items' do
    let(:valid_params) do
      {
        event_sponsorship_item: {
          item_type: 'in_kind',
          title: 'Marketing',
          total_value: 1000,
          received: true
        }
      }
    end

    it 'creates item and sets audit columns' do
      post "/v1/event_sponsorships/#{sponsorship.id}/event_sponsorship_items", 
           params: valid_params, 
           headers: { 'Authorization' => "Bearer #{org_owner_token}" }
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      item = EventSponsorshipItem.find(json['id'])
      expect(item.created_by_id).to eq(org_owner.id)
      expect(item.updated_by_id).to eq(org_owner.id)
      
      # Verify sponsorship received_total updated
      sponsorship.reload
      expect(sponsorship.received_total).to eq(1000)
    end
  end

  describe 'PATCH /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_items/:id' do
    let!(:item) { create(:event_sponsorship_item, event_sponsorship: sponsorship, total_value: 500, received: false) }
    
    it 'updates item and updates audit columns' do
      patch "/v1/event_sponsorships/#{sponsorship.id}/event_sponsorship_items/#{item.id}", 
            params: { event_sponsorship_item: { received: true } }, 
            headers: { 'Authorization' => "Bearer #{org_owner_token}" }
      
      expect(response).to have_http_status(:ok)
      expect(item.reload.received).to be true
      expect(item.updated_by_id).to eq(org_owner.id)
      
      # Verify sponsorship received_total updated
      sponsorship.reload
      expect(sponsorship.received_total).to eq(500)
    end
  end
end
