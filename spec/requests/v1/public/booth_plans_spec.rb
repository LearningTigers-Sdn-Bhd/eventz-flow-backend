require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorRegistrations#booth_plans', type: :request do
  let(:event) { create(:event) }

  describe 'GET /v1/public/events/:event_slug/booth_plans' do
    it 'returns active booth plans ordered by position' do
      create(:booth_plan, event: event, name: 'Sipadan I - III', position: 1)
      create(:booth_plan, event: event, name: 'Kinabatangan I - III', position: 0)
      create(:booth_plan, event: event, name: 'Hidden Plan', position: 2, active: false)

      get "/v1/public/events/#{event.slug}/booth_plans"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      names = json['data'].map { |plan| plan['name'] }
      expect(names).to eq(['Kinabatangan I - III', 'Sipadan I - III'])
    end

    it 'returns an empty array when no booth plans exist' do
      get "/v1/public/events/#{event.slug}/booth_plans"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']).to eq([])
    end

    it 'returns 404 for an unknown event slug' do
      get '/v1/public/events/does-not-exist/booth_plans'

      expect(response).to have_http_status(:not_found)
    end
  end
end
