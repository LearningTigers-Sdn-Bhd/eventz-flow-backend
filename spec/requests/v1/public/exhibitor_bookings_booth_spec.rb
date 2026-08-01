require 'rails_helper'

RSpec.describe 'Public exhibitor booking booth inventory', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor, email: 'vendor@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:token) do
    access, challenge = PublicExhibitorAccessSession.issue_challenge!(event: event, email: vendor.email)
    access.exchange_challenge!(challenge)
  end
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Idempotency-Key' => 'blocked-booth' } }
  let(:zone) { create(:exhibitor_zone, event: event) }
  let(:price) { create(:exhibitor_booth_price, event: event, exhibitor_zone: zone, price: 100) }

  it 'maps an unavailable booth to a conflict response' do
    exhibitor
    create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045',
      status: :blocked)

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: { exhibitor_booth_price_id: price.id, booth_number: 'S045', company_name: 'Acme',
                pic_full_name: 'Pat', pic_contact_number: '123', indemnity_signed: true },
      headers: headers

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.fetch('code')).to eq('booth_unavailable')
  end
end
