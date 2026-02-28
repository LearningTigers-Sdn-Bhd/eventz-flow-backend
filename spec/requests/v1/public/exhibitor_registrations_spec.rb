require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorRegistrations', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let!(:zone) { create(:exhibitor_zone, event: event, zone: 'zone_d', quota: 103) }
  let!(:booth_price) do
    create(
      :exhibitor_booth_price,
      event: event,
      exhibitor_zone: zone,
      booth_type: 'shell_scheme',
      label: 'Malaysian',
      price: 1500.00,
      quota: 30
    )
  end

  describe 'GET /v1/public/events/:event_slug/exhibitor_booth_prices' do
    it 'returns published event booth prices' do
      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']).to be_an(Array)
      expect(json['data'].first['label']).to eq('Malaysian')
      expect(json['data'].first['price'].to_f).to eq(1500.0)
      expect(json['data'].first['zone']).to eq('zone_d')
      expect(json['data'].first['zone_quota']).to eq(103)
      expect(json['data'].first['zone_sold_count']).to eq(0)
      expect(json['data'].first['zone_remaining']).to eq(103)
      expect(json['data'].first['zone_available']).to eq(true)
      expect(json['data'].first['booth_price_quota']).to eq(30)
      expect(json['data'].first['booth_price_sold_count']).to eq(0)
      expect(json['data'].first['booth_price_remaining']).to eq(30)
      expect(json['data'].first['booth_price_available']).to eq(true)
    end

    it 'marks booth price unavailable when zone quota is full even if booth quota remains' do
      booth_price.update!(quota: 8)
      zone.update!(quota: 10)
      other_price = create(
        :exhibitor_booth_price,
        event: event,
        exhibitor_zone: zone,
        booth_type: 'shell_scheme',
        label: 'International',
        price: 1800.00,
        quota: nil
      )

      10.times do
        create(
          :exhibitor_kit,
          event_vendor: create(:exhibitor, event: event),
          exhibitor_booth_price: other_price,
          payment_status: :unpaid
        )
      end

      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      malaysian = json['data'].find { |item| item['id'] == booth_price.id }
      expect(malaysian['zone_available']).to eq(false)
      expect(malaysian['booth_price_remaining']).to eq(8)
      expect(malaysian['booth_price_available']).to eq(false)
    end
  end

  describe 'POST /v1/public/events/:event_slug/register_exhibitor' do
    let(:email) { "amin-#{SecureRandom.hex(4)}@example.com" }

    let(:params) do
      {
        company_name: 'Acme Energy',
        company_address: 'Kota Kinabalu',
        name_on_fascia: 'ACME ENERGY',
        pic_full_name: 'Amin Rahman',
        pic_position: 'Sales Manager',
        pic_contact_number: '0123456789',
        pic_email_address: email,
        country: 'Malaysia',
        product_category: 'Oil & Gas Equipment',
        payment_option: 'later',
        exhibitor_booth_price_id: booth_price.id,
        custom_fields_data: {
          preferred_booth_location: 'Hall A',
          other_services: ['Advertising Opportunities']
        }
      }
    end

    it 'creates user, exhibitor, kit, and stores profile fields' do
      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      end.to change(User, :count).by(1)
                                 .and change(Exhibitor, :count).by(1)
                                                               .and change(ExhibitorKit, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['price'].to_f).to eq(1500.0)
      expect(json['data']['payment_required']).to be(false)
      expect(json['data']['payment_option']).to eq('later')

      kit = ExhibitorKit.order(created_at: :desc).first
      user = User.find_by!(email: email)
      expect(kit.country).to eq('Malaysia')
      expect(kit.name_on_fascia).to eq('ACME ENERGY')
      expect(kit.pic_position).to eq('Sales Manager')
      expect(kit.exhibitor_booth_price_id).to eq(booth_price.id)
      expect(kit.amount_paid.to_f).to eq(1500.0)
      expect(kit.payment_status).to eq('unpaid')
      expect(kit.custom_fields_data['preferred_booth_location']).to eq('Hall A')
      expect(kit.custom_fields_data['zone']).to eq('zone_d')
      expect(user.authenticate('OgseSabah123')).to eq(user)
      expect(user.vendor_profile.category).to eq('Oil & Gas Equipment')
      expect(user.vendor_profile.person_in_charge).to eq('Amin Rahman')
      expect(user.vendor_profile.address).to eq('Kota Kinabalu')
    end

    it 'returns payment_required true when payment option is now' do
      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params.merge(payment_option: 'now')

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['data']['payment_required']).to be(true)
      expect(json['data']['payment_option']).to eq('now')
    end

    it 'does not overwrite an existing registration for the same email' do
      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params
      existing_kit = ExhibitorKit.order(created_at: :desc).first

      expect do
        post "/v1/public/events/#{event.slug}/register_exhibitor", params: params.merge(company_name: 'Overwritten Co')
      end.to change(ExhibitorKit, :count).by(0)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['data']['already_registered']).to be(true)
      expect(json['data']['exhibitor_kit_id']).to eq(existing_kit.id)
      expect(existing_kit.reload.company_name).to eq('Acme Energy')
    end

    it 'returns 422 when the selected zone quota is full' do
      booth_price.update!(quota: nil)
      zone.update!(quota: 1)
      create(
        :exhibitor_kit,
        event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price,
        payment_status: :unpaid
      )

      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Selected zone is sold out')
    end

    it 'returns 422 when the selected booth price quota is full' do
      booth_price.update!(quota: 1)
      create(
        :exhibitor_kit,
        event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: booth_price,
        payment_status: :unpaid
      )

      post "/v1/public/events/#{event.slug}/register_exhibitor", params: params

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Selected booth package is sold out')
    end
  end

  describe 'GET /v1/public/events/:event_slug/exhibitor_registration_status' do
    let!(:vendor) do
      create(
        :user,
        :vendor,
        email: 'amin@example.com',
        full_name: 'Amin Rahman'
      )
    end
    let!(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
    let!(:exhibitor_kit) do
      exhibitor.exhibitor_kit.tap do |kit|
        kit.update!(
          exhibitor_booth_price: booth_price,
          pic_email_address: 'amin@example.com',
          payment_status: :paid
        )
      end
    end

    it 'returns existing registration status by email' do
      get "/v1/public/events/#{event.slug}/exhibitor_registration_status", params: { email: 'amin@example.com' }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['has_registered']).to be(true)
      expect(json['data']['exhibitor_kit_id']).to eq(exhibitor_kit.id)
      expect(json['data']['payment_status']).to eq('paid')
      expect(json['data']['company_name']).to eq(exhibitor_kit.company_name)
      expect(json['data']['pic_email_address']).to eq('amin@example.com')
      expect(json['data']['zone']).to eq('zone_d')
      expect(json['data']['payment_proof_uploaded']).to eq(false)
      expect(json['data']['payment_proof_url']).to be_nil
    end
  end

  describe 'POST /v1/public/events/:event_slug/exhibitor_payment_proof' do
    let!(:manual_zone) { create(:exhibitor_zone, event: event, zone: 'zone_a', quota: 10) }
    let!(:manual_booth_price) do
      create(
        :exhibitor_booth_price,
        event: event,
        exhibitor_zone: manual_zone,
        booth_type: 'raw_space',
        label: 'Diamond Package',
        price: 100_000.00
      )
    end
    let!(:manual_vendor) { create(:user, :vendor, email: 'manual@example.com') }
    let!(:manual_exhibitor) { create(:exhibitor, event: event, vendor: manual_vendor) }
    let!(:manual_kit) do
      create(
        :exhibitor_kit,
        event_vendor: manual_exhibitor,
        exhibitor_booth_price: manual_booth_price,
        pic_email_address: 'manual@example.com',
        custom_fields_data: { zone: 'zone_a' }
      )
    end

    it 'uploads payment proof for manual payment zones' do
      post "/v1/public/events/#{event.slug}/exhibitor_payment_proof",
           params: {
             exhibitor_kit_id: manual_kit.id,
             payment_proof: fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png')
           }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['exhibitor_kit_id']).to eq(manual_kit.id)
      expect(json['data']['payment_proof_uploaded']).to eq(true)
      expect(json['data']['payment_proof_url']).to be_present
      expect(manual_kit.reload.payment_proof).to be_attached
    end

    it 'rejects upload for non-manual payment zones' do
      non_manual_vendor = create(:user, :vendor, email: 'zoned@example.com')
      non_manual_exhibitor = create(:exhibitor, event: event, vendor: non_manual_vendor)
      non_manual_kit = create(
        :exhibitor_kit,
        event_vendor: non_manual_exhibitor,
        exhibitor_booth_price: booth_price,
        pic_email_address: 'zoned@example.com',
        custom_fields_data: { zone: 'zone_d' }
      )

      post "/v1/public/events/#{event.slug}/exhibitor_payment_proof",
           params: {
             exhibitor_kit_id: non_manual_kit.id,
             payment_proof: fixture_file_upload(Rails.root.join('spec', 'fixtures', 'test_image.png'), 'image/png')
           }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Payment proof upload is only required for Zone A, B, or C')
    end

    it 'rejects payment proof larger than 20MB' do
      temp_file = Tempfile.new(['large-receipt', '.pdf'])
      temp_file.binmode
      temp_file.write('a' * (20.megabytes + 1))
      temp_file.rewind

      uploaded_file = Rack::Test::UploadedFile.new(temp_file.path, 'application/pdf')

      post "/v1/public/events/#{event.slug}/exhibitor_payment_proof",
           params: {
             exhibitor_kit_id: manual_kit.id,
             payment_proof: uploaded_file
           }

      expect(response).to have_http_status(:unprocessable_content)
      json = JSON.parse(response.body)
      expect(json['success']).to be(false)
      expect(json['message']).to eq('Payment proof is too large (max 20MB)')
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  describe 'DELETE /v1/public/events/:event_slug/exhibitor_payment_proof' do
    let!(:manual_zone) { create(:exhibitor_zone, event: event, zone: 'zone_b', quota: 10) }
    let!(:manual_booth_price) do
      create(
        :exhibitor_booth_price,
        event: event,
        exhibitor_zone: manual_zone,
        booth_type: 'raw_space',
        label: 'Platinum Package',
        price: 75_000.00
      )
    end
    let!(:manual_vendor) { create(:user, :vendor, email: 'remove-proof@example.com') }
    let!(:manual_exhibitor) { create(:exhibitor, event: event, vendor: manual_vendor) }
    let!(:manual_kit) do
      create(
        :exhibitor_kit,
        event_vendor: manual_exhibitor,
        exhibitor_booth_price: manual_booth_price,
        pic_email_address: 'remove-proof@example.com',
        custom_fields_data: { zone: 'zone_b' }
      )
    end

    before do
      manual_kit.payment_proof.attach(
        io: File.open(Rails.root.join('spec', 'fixtures', 'test_image.png')),
        filename: 'test_image.png',
        content_type: 'image/png'
      )
    end

    it 'removes uploaded payment proof' do
      delete "/v1/public/events/#{event.slug}/exhibitor_payment_proof", params: { exhibitor_kit_id: manual_kit.id }

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      expect(json['data']['payment_proof_uploaded']).to eq(false)
      expect(json['data']['payment_proof_url']).to be_nil
      expect(manual_kit.reload.payment_proof).not_to be_attached
    end
  end
end
