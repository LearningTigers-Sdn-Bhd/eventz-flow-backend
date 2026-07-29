require 'rails_helper'

RSpec.describe 'Legacy public exhibitor endpoints', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }

  it 'returns gone without disclosing registration data or accepting mutations' do
    paths = [
      [:get, "/v1/public/events/#{event.slug}/exhibitor_registration_status"],
      [:post, "/v1/public/events/#{event.slug}/register_exhibitor"],
      [:patch, "/v1/public/events/#{event.slug}/register_exhibitor"],
      [:post, "/v1/public/events/#{event.slug}/exhibitor_payment_proof"],
      [:delete, "/v1/public/events/#{event.slug}/exhibitor_payment_proof"]
    ]

    paths.each do |method, path|
      public_send(method, path, params: { email: 'owner@example.com', exhibitor_kit_id: 1 })
      expect(response).to have_http_status(:gone)
      expect(response.parsed_body).to include('code' => 'legacy_exhibitor_endpoint_removed')
      expect(response.body).not_to include('owner@example.com')
    end
  end

  it 'removes legacy unauthenticated integer-kit payment routes' do
    post "/v1/public/events/#{event.slug}/exhibitor_payments/create_order", params: { exhibitor_kit_id: 1 }
    expect(response).to have_http_status(:not_found)

    post "/v1/public/events/#{event.slug}/exhibitor_payments/verify", params: { exhibitor_kit_id: 1 }
    expect(response).to have_http_status(:not_found)
  end
end
