require 'rails_helper'

RSpec.describe 'V1::ExhibitorBoothPrices', type: :request do
  let(:event) { create(:event) }
  let(:admin_user) { create(:user, :org_owner) }
  let(:member_user) { create(:user, :member) }
  let!(:zone) { create(:exhibitor_zone, event: event, zone: 'zone_d', quota: 103) }
  let!(:booth_price) do
    create(:exhibitor_booth_price, event: event, booth_type: 'shell_scheme', exhibitor_zone: zone, label: 'Malaysian')
  end

  describe 'GET /v1/events/:event_id/exhibitor_booth_prices' do
    it 'returns booth prices for org owner' do
      get "/v1/events/#{event.id}/exhibitor_booth_prices", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first['id']).to eq(booth_price.id)
      expect(json.first['zone']).to eq('zone_d')
      expect(json.first['exhibitor_zone_id']).to eq(zone.id)
      expect(json.first['current_price'].to_f).to eq(booth_price.price.to_f)
      expect(json.first['active_price_tier_label']).to be_nil
    end

    it 'returns active tier metadata when a tier is active' do
      create(
        :exhibitor_booth_price_tier,
        exhibitor_booth_price: booth_price,
        label: 'Early Bird',
        price: 1200,
        start_date: 1.day.ago,
        end_date: 1.day.from_now
      )

      get "/v1/events/#{event.id}/exhibitor_booth_prices", headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.first['current_price'].to_f).to eq(1200.0)
      expect(json.first['active_price_tier_label']).to eq('Early Bird')
    end

    it 'returns empty collection for member' do
      get "/v1/events/#{event.id}/exhibitor_booth_prices", headers: auth_headers(member_user)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to eq([])
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_booth_prices' do
    let(:params) do
      {
        exhibitor_booth_price: {
          booth_type: 'raw_space',
          exhibitor_zone_id: zone.id,
          label: 'International',
          price: 3000.00,
          quota: 30
        }
      }
    end

    it 'creates booth price for org owner' do
      expect do
        post "/v1/events/#{event.id}/exhibitor_booth_prices", params: params, headers: auth_headers(admin_user)
      end.to change(ExhibitorBoothPrice, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['zone']).to eq('zone_d')
      expect(json['exhibitor_zone_id']).to eq(zone.id)
      expect(json['quota']).to eq(30)
    end

    it 'rejects create when booth price quotas exceed zone quota' do
      zone.update!(quota: 40)
      create(
        :exhibitor_booth_price,
        event: event,
        booth_type: 'shell_scheme',
        exhibitor_zone: zone,
        label: 'Local',
        quota: 30
      )

      post "/v1/events/#{event.id}/exhibitor_booth_prices", params: params, headers: auth_headers(admin_user)

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['quota']).to include('total booth price quotas cannot exceed zone quota')
    end

    it 'forbids member' do
      post "/v1/events/#{event.id}/exhibitor_booth_prices", params: params, headers: auth_headers(member_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /v1/exhibitor_booth_prices/:id' do
    it 'updates booth price for org owner' do
      patch "/v1/exhibitor_booth_prices/#{booth_price.id}",
            params: { exhibitor_booth_price: { price: 1800.00, quota: 25 } },
            headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(booth_price.reload.price.to_f).to eq(1800.0)
      expect(booth_price.reload.quota).to eq(25)
    end

    it 'attaches zone when editing an unassigned booth price' do
      unassigned = create(
        :exhibitor_booth_price,
        event: event,
        booth_type: 'shell_scheme',
        exhibitor_zone: nil,
        label: 'No Zone Yet'
      )

      patch "/v1/exhibitor_booth_prices/#{unassigned.id}",
            params: { exhibitor_booth_price: { exhibitor_zone_id: zone.id } },
            headers: auth_headers(admin_user)

      expect(response).to have_http_status(:ok)
      expect(unassigned.reload.exhibitor_zone_id).to eq(zone.id)

      json = JSON.parse(response.body)
      expect(json['exhibitor_zone_id']).to eq(zone.id)
      expect(json['zone']).to eq(zone.zone)
    end
  end

  describe 'DELETE /v1/exhibitor_booth_prices/:id' do
    it 'deletes booth price for org owner' do
      expect do
        delete "/v1/exhibitor_booth_prices/#{booth_price.id}", headers: auth_headers(admin_user)
      end.to change(ExhibitorBoothPrice, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end
end
