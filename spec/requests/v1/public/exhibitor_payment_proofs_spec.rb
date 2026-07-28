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
    expect(kit.reload.exhibitor_registration_payment.payment_proof).to be_attached

    delete "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_proof", headers: headers
    expect(response).to have_http_status(:ok)
    expect(kit.reload.exhibitor_registration_payment.payment_proof).not_to be_attached
  end

  it 'stores proof on registration payment and marks it submitted' do
    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_proof",
      params: { payment_proof: proof }, headers: headers

    payment = kit.reload.exhibitor_registration_payment
    expect(payment).to be_present
    expect(payment.status).to eq('submitted')
    expect(payment.payment_proof).to be_attached
    expect(kit.payment_status).to eq('unpaid')
  end

  it 'clears the previous rejection note when proof is resubmitted' do
    payment = create(:exhibitor_registration_payment, exhibitor_kit: kit, status: 'rejected', note: 'Receipt looks edited')

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_proof",
      params: { payment_proof: proof }, headers: headers

    expect(payment.reload.status).to eq('submitted')
    expect(payment.note).to be_nil
  end

  it 'syncs registration payment when organizer marks the kit paid' do
    post "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}/payment_proof",
      params: { payment_proof: proof }, headers: headers

    kit.reload.update!(payment_status: :paid)

    expect(kit.exhibitor_registration_payment.reload.status).to eq('paid')
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
