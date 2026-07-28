require 'rails_helper'

RSpec.describe 'Public exhibitor payment proofs', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor, email: 'vendor@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:kit) { create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :unpaid) }
  let(:access) { PublicExhibitorAccessSession.issue_challenge!(event: event, email: vendor.email) }
  let(:token) { access.first.exchange_challenge!(access.last) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }
  let(:proof) do
    fixture_file_upload(Rails.root.join('spec/fixtures/test_image.png'), 'image/png')
  end

  it 'creates and deletes proof for session-owned booking public ID' do
    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_proof",
      params: { payment_proof: proof }, headers: headers
    expect(response).to have_http_status(:ok)
    expect(kit.reload.payment_proof).to be_attached

    delete "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_proof", headers: headers
    expect(response).to have_http_status(:ok)
    expect(kit.reload.payment_proof).not_to be_attached
  end

  it 'hides foreign bookings and validates files' do
    foreign = create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event))
    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{foreign.public_id}/payment_proof",
      params: { payment_proof: proof }, headers: headers
    expect(response).to have_http_status(:not_found)

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_proof",
      params: {}, headers: headers
    expect(response).to have_http_status(:unprocessable_content)
  end
end
