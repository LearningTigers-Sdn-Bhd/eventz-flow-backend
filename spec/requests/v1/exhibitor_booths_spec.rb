require 'rails_helper'

RSpec.describe 'V1::ExhibitorBooths', type: :request do
  let(:admin_user) { create(:user, :org_owner) }
  let(:member_user) { create(:user, :member) }
  let(:request_headers) { auth_headers(admin_user) }
  let(:event) { create(:event) }
  let(:zone) { create(:exhibitor_zone, event: event) }
  let(:price) { create(:exhibitor_booth_price, event: event, exhibitor_zone: zone) }

  describe 'GET /v1/events/:event_id/exhibitor_booths' do
    it 'lists booths with holder details for reserved rows' do
      exhibitor = create(:exhibitor, event: event)
      kit = create(:exhibitor_kit, event_vendor: exhibitor, company_name: 'Acme Sdn Bhd',
        booking_status: :active)
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045',
        status: :reserved, exhibitor_kit: kit)

      get "/v1/events/#{event.id}/exhibitor_booths", headers: request_headers

      expect(response).to have_http_status(:ok)
      row = response.parsed_body.first
      expect(row).to include('number' => 'S045', 'status' => 'reserved',
        'held_by' => 'Acme Sdn Bhd')
      expect(row['held_since']).to be_present
    end

    it 'filters by status' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045')
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S046',
        status: :blocked)

      get "/v1/events/#{event.id}/exhibitor_booths", params: { status: 'blocked' },
        headers: request_headers

      expect(response.parsed_body.pluck('number')).to eq(%w[S046])
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_booths/bulk' do
    it 'creates many booths at once' do
      post "/v1/events/#{event.id}/exhibitor_booths/bulk",
        params: { exhibitor_booths: { exhibitor_booth_price_id: price.id,
                                      numbers: %w[S045 s046 S047] } },
        headers: request_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(event.exhibitor_booths.pluck(:number)).to contain_exactly('S045', 'S046', 'S047')
    end

    it 'creates nothing when one number is a duplicate' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045')

      post "/v1/events/#{event.id}/exhibitor_booths/bulk",
        params: { exhibitor_booths: { exhibitor_booth_price_id: price.id,
                                      numbers: %w[S048 S045] } },
        headers: request_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(event.exhibitor_booths.count).to eq(1)
    end
  end

  describe 'POST /v1/exhibitor_booths/:id/release' do
    it 'frees a held booth and clears the booking snapshot' do
      exhibitor = create(:exhibitor, event: event)
      kit = create(:exhibitor_kit, event_vendor: exhibitor, booth_number: 'S045',
        booking_status: :active)
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045',
        status: :reserved, exhibitor_kit: kit)

      post "/v1/exhibitor_booths/#{booth.id}/release", headers: request_headers

      expect(response).to have_http_status(:ok)
      expect(booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
      expect(kit.reload.booth_number).to be_nil
    end
  end

  describe 'DELETE /v1/exhibitor_booths/:id' do
    it 'deletes an available booth' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price)

      delete "/v1/exhibitor_booths/#{booth.id}", headers: request_headers

      expect(response).to have_http_status(:no_content)
    end

    it 'refuses to delete a reserved or booked booth' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :booked)

      delete "/v1/exhibitor_booths/#{booth.id}", headers: request_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(booth.reload).to be_persisted
    end
  end
end
