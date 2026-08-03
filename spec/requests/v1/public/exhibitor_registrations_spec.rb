require 'rails_helper'

RSpec.describe 'V1::Public::ExhibitorRegistrations', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let!(:zone) { create(:exhibitor_zone, event: event, zone: 'zone_d', quota: 103) }
  let!(:booth_price) do
    create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
      booth_type: 'shell_scheme', label: 'Malaysian', price: 1500.00, quota: 30)
  end

  describe 'POST /v1/public/events/:event_slug/exhibitor_ic_upload' do
    it 'uploads an event-bound IC copy and returns a signed ID' do
      post "/v1/public/events/#{event.slug}/exhibitor_ic_upload",
        params: { file: fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png') }

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body).fetch('data')
      blob = ActiveStorage::Blob.find_signed!(data.fetch('signed_id'))
      expect(blob.metadata).to include('document_key' => 'exhibitor_ic_copy', 'event_id' => event.id)
    end

    it 'rejects unsupported files' do
      file = Tempfile.new(['ic', '.txt'])
      file.write('not an image')
      file.rewind

      post "/v1/public/events/#{event.slug}/exhibitor_ic_upload",
        params: { file: Rack::Test::UploadedFile.new(file.path, 'text/plain') }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to eq('IC copy must be a JPEG, PNG, WebP, or PDF')
    ensure
      file.close!
    end
  end

  describe 'POST /v1/public/events/:event_slug/customs_declaration_upload' do
    it 'uploads an event-bound customs declaration up to 20MB' do
      file = Tempfile.new(['customs-declaration', '.pdf'])
      file.truncate(15.megabytes)

      post "/v1/public/events/#{event.slug}/customs_declaration_upload",
        params: { file: Rack::Test::UploadedFile.new(file.path, 'application/pdf') }

      expect(response).to have_http_status(:created)
      blob = ActiveStorage::Blob.find_signed!(response.parsed_body.dig('data', 'signed_id'))
      expect(blob.metadata).to include('document_key' => 'customs_declaration_form', 'event_id' => event.id)
    ensure
      file.close!
    end

    it 'rejects customs declarations larger than 20MB' do
      file = Tempfile.new(['customs-declaration', '.pdf'])
      file.truncate(20.megabytes + 1)

      post "/v1/public/events/#{event.slug}/customs_declaration_upload",
        params: { file: Rack::Test::UploadedFile.new(file.path, 'application/pdf') }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['message']).to eq('Customs declaration form is too large (max 20MB)')
    ensure
      file.close!
    end
  end

  describe 'GET /v1/public/events/:event_slug/exhibitor_booth_prices' do
    it 'returns published event booth prices' do
      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json['success']).to be(true)
      booth = json['data'].first
      expect(booth).to include(
        'label' => 'Malaysian', 'zone' => 'zone_d',
        'zone_quota' => 103, 'zone_remaining' => 103,
        'zone_available' => true, 'booth_price_quota' => 30,
        'booth_price_remaining' => 30, 'booth_price_available' => true
      )
      expect(booth['price'].to_f).to eq(1500.0)
      expect(booth['base_price'].to_f).to eq(1500.0)
    end

    it 'returns the active tier price when a booth tier is active' do
      create(:exhibitor_booth_price_tier, exhibitor_booth_price: booth_price,
        label: 'Early Bird', price: 1200, start_date: 1.day.ago, end_date: 1.day.from_now)

      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      booth = JSON.parse(response.body)['data'].first
      expect(booth['price'].to_f).to eq(1200.0)
      expect(booth['base_price'].to_f).to eq(1500.0)
      expect(booth['active_price_tier_label']).to eq('Early Bird')
    end

    it 'exposes packages attached to each booth price' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price,
        name: 'Package A | Standard Booth', price: 7000.0, quota: 40, inclusions: '6D5N hotel')

      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      payload = json_response['data'].find { |row| row['id'] == booth_price.id }
      expect(payload['packages'].size).to eq(1)
      expect(payload['packages'].first).to include(
        'id' => package.id, 'name' => 'Package A | Standard Booth', 'inclusions' => '6D5N hotel',
        'quota' => 40, 'remaining' => 40, 'available' => true
      )
      expect(payload['packages'].first['price'].to_f).to eq(7000.0)
    end

    it 'marks a package unavailable when its quota is consumed' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: 1)
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event), exhibitor_booth_price: booth_price,
        exhibitor_package: package, booth_quantity: 1, booking_status: :paid)

      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      payload = json_response['data'].find { |row| row['id'] == booth_price.id }
      expect(payload['packages'].first).to include('sold_count' => 1, 'remaining' => 0, 'available' => false)
    end

    it 'reports an unlimited package as available' do
      create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: nil)

      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      payload = json_response['data'].find { |row| row['id'] == booth_price.id }
      expect(payload['packages'].first).to include('quota' => nil, 'remaining' => nil, 'available' => true)
    end

    it 'marks booth price unavailable when zone quota is full even if booth quota remains' do
      booth_price.update!(quota: 8)
      zone.update!(quota: 10)
      other_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
        booth_type: 'shell_scheme', label: 'International', price: 1800.00, quota: nil)
      10.times do
        create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event),
          exhibitor_booth_price: other_price, payment_status: :unpaid)
      end

      get "/v1/public/events/#{event.slug}/exhibitor_booth_prices"

      expect(response).to have_http_status(:ok)
      booth = JSON.parse(response.body)['data'].find { |item| item['id'] == booth_price.id }
      expect(booth).to include(
        'zone_available' => false, 'booth_price_remaining' => 8,
        'booth_price_available' => false
      )
    end
  end
end
