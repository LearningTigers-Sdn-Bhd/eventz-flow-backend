require 'rails_helper'

RSpec.describe 'V1::ExhibitorBoothPriceTiers', type: :request do
  let(:event) { create(:event) }
  let(:admin_user) { create(:user, :org_owner) }
  let(:member_user) { create(:user, :member) }
  let(:booth_price) { create(:exhibitor_booth_price, event: event) }
  let!(:price_tier) do
    create(
      :exhibitor_booth_price_tier,
      exhibitor_booth_price: booth_price,
      label: 'Early Bird',
      price: 1200,
      start_date: 1.day.ago,
      end_date: 1.day.from_now
    )
  end

  describe 'GET /v1/exhibitor_booth_prices/:exhibitor_booth_price_id/price_tiers' do
    it 'returns price tiers for org owner' do
      get "/v1/exhibitor_booth_prices/#{booth_price.id}/price_tiers", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first['label']).to eq('Early Bird')
      expect(json.first['active']).to eq(true)
    end

    it 'returns empty collection for member' do
      get "/v1/exhibitor_booth_prices/#{booth_price.id}/price_tiers", headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end
  end

  describe 'POST /v1/exhibitor_booth_prices/:exhibitor_booth_price_id/price_tiers' do
    let(:params) do
      {
        exhibitor_booth_price_tier: {
          label: 'Standard',
          price: 1500,
          start_date: 2.days.from_now.iso8601,
          end_date: 5.days.from_now.iso8601
        }
      }
    end

    it 'creates a price tier for org owner' do
      expect do
        post "/v1/exhibitor_booth_prices/#{booth_price.id}/price_tiers", params: params, headers: auth_headers(admin_user)
      end.to change(ExhibitorBoothPriceTier, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['label']).to eq('Standard')
      expect(json['price'].to_f).to eq(1500.0)
    end

    it 'forbids member' do
      post "/v1/exhibitor_booth_prices/#{booth_price.id}/price_tiers", params: params, headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /v1/exhibitor_booth_prices/:exhibitor_booth_price_id/price_tiers/:id' do
    it 'updates a price tier for org owner' do
      patch "/v1/exhibitor_booth_prices/#{booth_price.id}/price_tiers/#{price_tier.id}",
            params: { exhibitor_booth_price_tier: { price: 1100, label: 'Super Early Bird' } },
            headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(price_tier.reload.price.to_f).to eq(1100.0)
      expect(price_tier.label).to eq('Super Early Bird')
    end
  end

  describe 'DELETE /v1/exhibitor_booth_prices/:exhibitor_booth_price_id/price_tiers/:id' do
    it 'deletes a price tier for org owner' do
      expect do
        delete "/v1/exhibitor_booth_prices/#{booth_price.id}/price_tiers/#{price_tier.id}", headers: auth_headers(admin_user)
      end.to change(ExhibitorBoothPriceTier, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
