require 'rails_helper'

RSpec.describe 'V1::EventSponsorshipPayments', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  
  let(:event) { create(:event) }
  let(:sponsorship) { create(:event_sponsorship, event: event) }
  
  describe 'POST /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_payments' do
    let(:valid_params) do
      {
        event_sponsorship_payment: {
          amount: 1000,
          received_at: Time.current,
          method: 'bank_transfer'
        }
      }
    end

    it 'creates payment and sets audit columns' do
      post "/v1/event_sponsorships/#{sponsorship.id}/event_sponsorship_payments", 
           params: valid_params, 
           headers: { 'Authorization' => "Bearer #{org_owner_token}" }
      
      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      
      payment = EventSponsorshipPayment.find(json['id'])
      expect(payment.created_by_id).to eq(org_owner.id)
      expect(payment.updated_by_id).to eq(org_owner.id)
    end
  end

  describe 'PATCH /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_payments/:id' do
    let!(:payment) { create(:event_sponsorship_payment, event_sponsorship: sponsorship, amount: 500) }
    
    it 'updates payment and updates audit columns' do
      patch "/v1/event_sponsorships/#{sponsorship.id}/event_sponsorship_payments/#{payment.id}", 
            params: { event_sponsorship_payment: { amount: 1500 } }, 
            headers: { 'Authorization' => "Bearer #{org_owner_token}" }
      
      expect(response).to have_http_status(:ok)
      expect(payment.reload.amount).to eq(1500)
      expect(payment.updated_by_id).to eq(org_owner.id)
    end
  end
end
