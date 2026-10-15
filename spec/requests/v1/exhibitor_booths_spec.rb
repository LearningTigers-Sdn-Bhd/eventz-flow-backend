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

    it 'skips duplicate numbers and creates the rest' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045')

      post "/v1/events/#{event.id}/exhibitor_booths/bulk",
        params: { exhibitor_booths: { exhibitor_booth_price_id: price.id,
                                      numbers: %w[S048 S045] } },
        headers: request_headers, as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body['skipped_count']).to eq(1)
      expect(event.exhibitor_booths.pluck(:number)).to contain_exactly('S045', 'S048')
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

  describe 'POST /v1/exhibitor_booths/:id/assign' do
    let(:exhibitor) { create(:exhibitor, event: event) }
    let(:kit) { create(:exhibitor_kit, event_vendor: exhibitor, booth_number: nil) }
    let(:booth) do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045')
    end
    let(:assign_params) { { exhibitor_booth: { exhibitor_kit_id: kit.id } } }

    it 'assigns an available booth to a kit in the same event' do
      post "/v1/exhibitor_booths/#{booth.id}/assign", params: assign_params,
        headers: request_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(booth.reload).to have_attributes(status: 'booked', exhibitor_kit_id: kit.id)
      expect(kit.reload.booth_number).to eq('S045')
    end

    it 'assigns a booth matching the kit own booth price' do
      priced_kit = create(:exhibitor_kit, event_vendor: exhibitor, booth_number: nil,
        exhibitor_booth_price: price)

      post "/v1/exhibitor_booths/#{booth.id}/assign",
        params: { exhibitor_booth: { exhibitor_kit_id: priced_kit.id } },
        headers: request_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(booth.reload).to have_attributes(status: 'booked', exhibitor_kit_id: priced_kit.id)
    end

    it 'rejects a booth from a different price tier than the kit was billed at' do
      other_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone)
      priced_kit = create(:exhibitor_kit, event_vendor: exhibitor, booth_number: nil,
        exhibitor_booth_price: other_price)

      post "/v1/exhibitor_booths/#{booth.id}/assign",
        params: { exhibitor_booth: { exhibitor_kit_id: priced_kit.id } },
        headers: request_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include("Booth does not match the kit's booth price")
      expect(booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
      expect(priced_kit.reload.booth_number).to be_nil
    end

    it 'rejects a booth booked by a different kit without changing state' do
      other_kit = create(:exhibitor_kit, event_vendor: exhibitor, booth_number: 'S045')
      booth.update!(status: :booked, exhibitor_kit: other_kit)

      post "/v1/exhibitor_booths/#{booth.id}/assign", params: assign_params,
        headers: request_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(booth.reload).to have_attributes(status: 'booked', exhibitor_kit_id: other_kit.id)
      expect(kit.reload.booth_number).to be_nil
    end

    it 'allows assigning the kit own booth again' do
      booth.update!(status: :booked, exhibitor_kit: kit)
      kit.update!(booth_number: booth.number)

      post "/v1/exhibitor_booths/#{booth.id}/assign", params: assign_params,
        headers: request_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(booth.reload).to have_attributes(status: 'booked', exhibitor_kit_id: kit.id)
      expect(kit.reload.booth_number).to eq('S045')
    end

    it 'releases the kit previous booth when assigning another booth' do
      old_booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price,
        number: 'S044', status: :booked, exhibitor_kit: kit)
      kit.update!(booth_number: old_booth.number)

      post "/v1/exhibitor_booths/#{booth.id}/assign", params: assign_params,
        headers: request_headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(old_booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
      expect(booth.reload).to have_attributes(status: 'booked', exhibitor_kit_id: kit.id)
      expect(kit.reload.booth_number).to eq('S045')
    end

    it 'rejects a kit from another event without changing state' do
      other_event = create(:event)
      other_exhibitor = create(:exhibitor, event: other_event)
      other_kit = create(:exhibitor_kit, event_vendor: other_exhibitor, booth_number: nil)

      post "/v1/exhibitor_booths/#{booth.id}/assign",
        params: { exhibitor_booth: { exhibitor_kit_id: other_kit.id } },
        headers: request_headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
      expect(other_kit.reload.booth_number).to be_nil
    end

    it 'forbids a vendor from assigning a booth without changing state' do
      vendor = create(:user, :vendor)

      post "/v1/exhibitor_booths/#{booth.id}/assign", params: assign_params,
        headers: auth_headers(vendor), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
      expect(kit.reload.booth_number).to be_nil
    end

    it 'returns not found for an unknown exhibitor kit' do
      post "/v1/exhibitor_booths/#{booth.id}/assign",
        params: { exhibitor_booth: { exhibitor_kit_id: 0 } },
        headers: request_headers, as: :json

      expect(response).to have_http_status(:not_found)
      expect(booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
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
