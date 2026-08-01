require 'rails_helper'

RSpec.describe 'Public exhibitor booking batches', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor, email: 'owner@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:token) do
    access, challenge = PublicExhibitorAccessSession.issue_challenge!(event: event, email: vendor.email)
    access.exchange_challenge!(challenge)
  end
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Idempotency-Key' => SecureRandom.uuid } }
  let!(:standard) { create(:exhibitor_booth_price, event: event, price: 100, exhibitor_zone: create(:exhibitor_zone, event: event, zone: 'standard')) }
  let!(:premium) { create(:exhibitor_booth_price, event: event, price: 250, exhibitor_zone: create(:exhibitor_zone, event: event, zone: 'premium')) }
  let(:params) do
    { company_name: 'Acme', pic_full_name: 'Owner', pic_contact_number: '0123456789', indemnity_signed: true,
      booths: [
        { exhibitor_booth_price_id: standard.id, booth_number: 'A-1' },
        { exhibitor_booth_price_id: premium.id, booth_number: 'B-2' },
        { exhibitor_booth_price_id: standard.id, booth_number: 'A-3' }
      ] }
  end

  it 'creates mixed-price booths with one batch id and summed amount' do
    exhibitor

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/batch", params: params, headers: headers

    expect(response).to have_http_status(:created)
    data = response.parsed_body.fetch('data')
    expect(data.fetch('kits')).to have_attributes(length: 3)
    expect(data.fetch('combined_amount').to_f).to eq(450)
    expect(data.fetch('kits').map { |kit| kit.fetch('booking_batch_id') }.uniq).to eq([data.fetch('batch_id')])
  end

  it 'rolls back every booth and identifies duplicate booth number' do
    exhibitor
    duplicate_params = params.deep_dup
    duplicate_params[:booths][1][:booth_number] = 'A-1'

    expect {
      post "/v1/public/events/#{event.slug}/exhibitor_bookings/batch", params: duplicate_params, headers: headers
    }.not_to change(ExhibitorKit, :count)

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body).to include('code' => 'duplicate_booth_number', 'failed_booth_number' => 'A-1')
  end

  it 'rolls back every booth when a later package is sold out' do
    exhibitor
    premium.update!(quota: 0)

    expect {
      post "/v1/public/events/#{event.slug}/exhibitor_bookings/batch", params: params, headers: headers
    }.not_to change(ExhibitorKit, :count)

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.fetch('code')).to eq('booth_sold_out')
  end

  it 'reuses batch uploads but rejects a blob from a prior booking' do
    exhibitor
    ic_copy = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('identity'), filename: 'ic.pdf',
      content_type: 'application/pdf', metadata: { document_key: 'exhibitor_ic_copy', event_id: event.id })
    customs = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('declaration'), filename: 'customs.pdf',
      content_type: 'application/pdf', metadata: { document_key: 'customs_declaration_form', event_id: event.id })

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/batch",
      params: params.merge(ic_copy_signed_id: ic_copy.signed_id, customs_declaration_signed_id: customs.signed_id), headers: headers

    expect(response).to have_http_status(:created)
    expect(exhibitor.exhibitor_kits.last(3)).to all(have_attributes(ic_copy: have_attributes(blob: ic_copy)))
    expect(exhibitor.exhibitor_kits.last(3)).to all(have_attributes(customs_declaration_form: have_attributes(blob: customs)))

    other_booths_params = params.deep_dup
    other_booths_params[:booths].each_with_index { |booth, index| booth[:booth_number] = "C-#{index + 1}" }

    post "/v1/public/events/#{event.slug}/exhibitor_bookings/batch",
      params: other_booths_params.merge(ic_copy_signed_id: ic_copy.signed_id), headers: headers.merge('Idempotency-Key' => SecureRandom.uuid)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body.fetch('code')).to eq('ic_copy_invalid')
  end
end
