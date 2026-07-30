require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorBooths' do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:zone) { create(:exhibitor_zone, event: event) }
  let(:price) { create(:exhibitor_booth_price, event: event, exhibitor_zone: zone) }
  let(:path) { "/v1/public/events/#{event.slug}/exhibitor_booths" }

  it 'lists only bookable booths for the given price, ordered by number' do
    create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S046')
    create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045')
    create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S047',
      status: :blocked)

    get path, params: { exhibitor_booth_price_id: price.id }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body['data'].pluck('number')).to eq(%w[S045 S046])
  end

  it 'excludes booths belonging to another price' do
    other_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone)
    create(:exhibitor_booth, event: event, exhibitor_booth_price: other_price, number: 'K101')

    get path, params: { exhibitor_booth_price_id: price.id }

    expect(response.parsed_body['data']).to be_empty
  end

  it 'returns 404 for a price that is not part of the event' do
    foreign_price = create(:exhibitor_booth_price, event: create(:event))

    get path, params: { exhibitor_booth_price_id: foreign_price.id }

    expect(response).to have_http_status(:not_found)
  end

  describe 'booth number availability on an inventory event' do
    let(:availability_path) { "/v1/public/events/#{event.slug}/exhibitor_booth_number_availability" }
    let(:vendor) { create(:user, :vendor, email: 'vendor@example.com') }
    let(:token) do
      access, challenge = PublicExhibitorAccessSession.issue_challenge!(event: event, email: vendor.email)
      access.exchange_challenge!(challenge)
    end

    it 'reports an unknown number as unavailable' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045')

      get availability_path, params: { booth_number: 'S999' },
        headers: { 'Authorization' => "Bearer #{token}" }

      expect(response.parsed_body.dig('data', 'available')).to be(false)
    end
  end
end
