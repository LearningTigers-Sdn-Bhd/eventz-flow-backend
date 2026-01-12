require 'rails_helper'

RSpec.describe 'V1::Sponsors', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }
  
  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member)[:access_token] }

  let!(:group) { create(:group) }
  
  before do
    # Add organizer to group so group_id derivation works for them
    group.group_members.create!(user: organizer, has_manager_access: true)
  end

  describe 'POST /v1/sponsors' do
    let(:valid_params) do
      {
        sponsor: {
          name: 'New Sponsor',
          industry: 'Tech'
        }
      }
    end

    context 'as Org Owner' do
      it 'creates sponsor and auto-assigns group_id from first visible group' do
        post '/v1/sponsors', params: valid_params, headers: { 'Authorization' => "Bearer #{org_owner_token}" }
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['name']).to eq('New Sponsor')
        expect(json['group_id']).to eq(group.id)
      end
    end

    context 'as Organizer' do
      it 'creates sponsor and auto-assigns group_id from user groups' do
        post '/v1/sponsors', params: valid_params, headers: { 'Authorization' => "Bearer #{organizer_token}" }
        
        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['group_id']).to eq(group.id)
      end
    end

    context 'as Member' do
      it 'returns 403 Forbidden' do
        post '/v1/sponsors', params: valid_params, headers: { 'Authorization' => "Bearer #{member_token}" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'GET /v1/sponsors/:id' do
    let!(:sponsor) { create(:sponsor, group: group) }
    let!(:event) { create(:event) }
    let!(:sponsorship) { create(:event_sponsorship, sponsor: sponsor, event: event, total_sponsor_amount: 1000) }
    
    before do
      create(:event_sponsorship_payment, event_sponsorship: sponsorship, amount: 500)
    end

    it 'returns sponsor with analytics and history' do
      get "/v1/sponsors/#{sponsor.id}", headers: { 'Authorization' => "Bearer #{org_owner_token}" }
      
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      
      expect(json['total_sponsorship_count']).to eq(1)
      expect(json['total_pledged_amount']).to eq("1000.0")
      expect(json['total_received_amount']).to eq("500.0")
      expect(json['event_sponsorships']).to be_present
      expect(json['event_sponsorships'].first['event']).to be_present
      expect(json['event_sponsorships'].first['event']['title']).to eq(event.title)
    end
  end
end
