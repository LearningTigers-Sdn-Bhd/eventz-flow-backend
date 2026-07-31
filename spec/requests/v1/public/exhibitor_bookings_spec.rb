require 'rails_helper'

RSpec.describe 'Public exhibitor bookings', type: :request do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor, email: 'owner@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:token) do
    access, challenge = PublicExhibitorAccessSession.issue_challenge!(event: event, email: vendor.email)
    access.exchange_challenge!(challenge)
  end
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  it 'creates a packaged booking priced from the package' do
    booth_price = create(:exhibitor_booth_price, event: event, price: 5000.00)
    package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, price: 7000.00)
    valid_booking_params = {
      exhibitor_booth_price_id: booth_price.id, company_name: 'Acme', pic_full_name: 'Owner',
      pic_contact_number: '0123456789', indemnity_signed: true
    }

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: valid_booking_params.merge(exhibitor_package_id: package.id),
      headers: headers.merge('Idempotency-Key' => SecureRandom.uuid)

    expect(response).to have_http_status(:created)
    expect(json_response['data']['amount'].to_f).to eq(7000.00)
  end

  it 'returns 422 package_mismatch for a package on another booth price' do
    booth_price = create(:exhibitor_booth_price, event: event, price: 5000.00)
    other_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: booth_price.exhibitor_zone)
    foreign = create(:exhibitor_package, event: event, exhibitor_booth_price: other_price)
    valid_booking_params = {
      exhibitor_booth_price_id: booth_price.id, company_name: 'Acme', pic_full_name: 'Owner',
      pic_contact_number: '0123456789', indemnity_signed: true
    }

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: valid_booking_params.merge(exhibitor_package_id: foreign.id),
      headers: headers.merge('Idempotency-Key' => SecureRandom.uuid)

    expect(response).to have_http_status(:unprocessable_content)
    expect(json_response['code']).to eq('package_mismatch')
  end

  it 'prices a new booking from a voucher and redeems it' do
    booth_price = create(:exhibitor_booth_price, event: event, price: 1000)
    voucher = create(:exhibitor_voucher, :fixed_amount, event: event, discount_value: 400)

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: {
        exhibitor_booth_price_id: booth_price.id,
        voucher_code: voucher.code,
        company_name: 'Acme',
        pic_full_name: 'Owner',
        pic_contact_number: '0123456789',
        indemnity_signed: true
      },
      headers: headers.merge('Idempotency-Key' => SecureRandom.uuid)

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig('data', 'amount').to_f).to eq(600)
    created_kit = event.exhibitors.find_by!(vendor: vendor).exhibitor_kits.last
    expect(voucher.reload).to have_attributes(
      status: 'redeemed',
      redeemed_by_exhibitor_kit_id: created_kit.id
    )
  end

  it 'rejects an already-redeemed voucher code' do
    booth_price = create(:exhibitor_booth_price, event: event, price: 1000)
    voucher = create(:exhibitor_voucher, :redeemed, event: event)

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: {
        exhibitor_booth_price_id: booth_price.id,
        voucher_code: voucher.code,
        company_name: 'Acme',
        pic_full_name: 'Owner',
        pic_contact_number: '0123456789',
        indemnity_signed: true
      },
      headers: headers.merge('Idempotency-Key' => SecureRandom.uuid)

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body).to include(
      'code' => 'voucher_invalid',
      'message' => 'Voucher code is invalid or already used'
    )
  end

  it 'rolls back voucher redemption when booking creation fails afterward' do
    booth_price = create(:exhibitor_booth_price, event: event, price: 1000)
    voucher = create(:exhibitor_voucher, event: event)

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: {
        exhibitor_booth_price_id: booth_price.id,
        voucher_code: voucher.code,
        company_name: 'Acme',
        pic_full_name: 'Owner',
        pic_contact_number: '0123456789',
        indemnity_signed: true,
        ic_copy_signed_id: 'invalid-signed-id'
      },
      headers: headers.merge('Idempotency-Key' => SecureRandom.uuid)

    expect(response).to have_http_status(:unprocessable_content)
    expect(voucher.reload).to be_active
    expect(exhibitor.exhibitor_kits).to be_empty
  end

  it 'returns null exhibitor_package for a Local booking' do
    booth_price = create(:exhibitor_booth_price, event: event)
    kit = create(:exhibitor_kit, event_vendor: exhibitor, exhibitor_booth_price: booth_price)

    get "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}", headers: headers

    expect(json_response['data']['exhibitor_package']).to be_nil
  end

  it 'returns the package on a packaged booking' do
    booth_price = create(:exhibitor_booth_price, event: event)
    package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price,
      name: 'Package A | Standard Booth', price: 7000.0, inclusions: '6D5N hotel')
    kit = create(:exhibitor_kit, event_vendor: exhibitor, exhibitor_booth_price: booth_price,
      exhibitor_package: package)

    get "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}", headers: headers

    expect(json_response['data']['exhibitor_package']).to include(
      'id' => package.id, 'name' => 'Package A | Standard Booth', 'inclusions' => '6D5N hotel'
    )
    expect(json_response['data']['exhibitor_package_id']).to eq(package.id)
  end

  it 'creates first booking from a new-registration token and returns a payment session' do
    new_email = 'brand-new@example.com'
    post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: new_email }
    registration_token = response.parsed_body.dig('data', 'new_registration_token')
    new_headers = { 'X-New-Registration-Token' => registration_token, 'Idempotency-Key' => 'first-booking' }
    price = create(:exhibitor_booth_price, event: event, price: 100)
    params = { exhibitor_booth_price_id: price.id, company_name: 'New Co', pic_full_name: 'New Owner',
               pic_contact_number: '0123456789', indemnity_signed: true }

    post "/v1/public/events/#{event.slug}/exhibitor_bookings", params: params, headers: new_headers

    user = User.find_by!(email: new_email)
    expect(User.where(email: new_email).count).to eq(1)
    expect(event.exhibitors.where(vendor: user).count).to eq(1)
    expect(event.exhibitors.find_by!(vendor: user).exhibitor_kits.count).to eq(1)
    session_token = response.parsed_body.dig('meta', 'session_token')
    expect(session_token).to be_present
    expect(PublicExhibitorAccessSession.authenticate(event: event, token: session_token).normalized_email).to eq(new_email)
  end

  it 'rejects a new-registration token when an account appeared before create' do
    new_email = 'raced@example.com'
    post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: new_email }
    registration_token = response.parsed_body.dig('data', 'new_registration_token')
    create(:user, :vendor, email: new_email.upcase)
    price = create(:exhibitor_booth_price, event: event, price: 100)

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: { exhibitor_booth_price_id: price.id, company_name: 'Raced Co', pic_full_name: 'Owner',
                 pic_contact_number: '0123456789', indemnity_signed: true },
      headers: { 'X-New-Registration-Token' => registration_token, 'Idempotency-Key' => 'raced-booking' }

    expect(response).to have_http_status(:conflict)
    expect(response.parsed_body.fetch('code')).to eq('email_requires_access')
    expect(ExhibitorKit.where(event_vendor: event.exhibitors)).to be_empty
  end

  it 'does not accept a new-registration token for another event' do
    post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: 'new@example.com' }
    registration_token = response.parsed_body.dig('data', 'new_registration_token')
    other_event = create(:event, status: :published, use_exhibitor_kit: true)
    price = create(:exhibitor_booth_price, event: other_event, price: 100)

    post "/v1/public/events/#{other_event.slug}/exhibitor_bookings",
      params: { exhibitor_booth_price_id: price.id, company_name: 'Wrong Event', pic_full_name: 'Owner',
                   pic_contact_number: '0123456789', indemnity_signed: true },
      headers: { 'X-New-Registration-Token' => registration_token, 'Idempotency-Key' => 'wrong-event' }

    expect(response).to have_http_status(:unauthorized)
  end

  it 'does not accept a new-registration token for listing bookings or after expiry' do
    post "/v1/public/events/#{event.slug}/exhibitor_email_status", params: { email: 'new@example.com' }
    registration_token = response.parsed_body.dig('data', 'new_registration_token')

    get "/v1/public/events/#{event.slug}/exhibitor_bookings",
      headers: { 'X-New-Registration-Token' => registration_token }
    expect(response).to have_http_status(:unauthorized)

    travel 2.hours + 1.second do
      price = create(:exhibitor_booth_price, event: event, price: 100)
      post "/v1/public/events/#{event.slug}/exhibitor_bookings",
        params: { exhibitor_booth_price_id: price.id, company_name: 'Expired', pic_full_name: 'Owner',
                  pic_contact_number: '0123456789' },
        headers: { 'X-New-Registration-Token' => registration_token, 'Idempotency-Key' => 'expired-token' }
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it 'attaches an event-bound IC copy to a new booking' do
    price = create(:exhibitor_booth_price, event: event, price: 100)
    blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('identity'), filename: 'ic.pdf',
      content_type: 'application/pdf', metadata: { document_key: 'exhibitor_ic_copy', event_id: event.id })
    exhibitor

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: { exhibitor_booth_price_id: price.id, company_name: 'Acme', pic_full_name: 'Owner',
                 pic_contact_number: '0123456789', indemnity_signed: true,
                ic_copy_signed_id: blob.signed_id },
      headers: headers.merge('Idempotency-Key' => 'booking-with-ic')

    expect(response).to have_http_status(:created)
    expect(exhibitor.exhibitor_kits.find_by!(idempotency_key: 'booking-with-ic').ic_copy.blob).to eq(blob)
  end

  it 'reports whether booking detail has an IC copy without exposing blob credentials' do
    kit = create(:exhibitor_kit, event_vendor: exhibitor)
    kit.ic_copy.attach(io: StringIO.new('identity'), filename: 'ic.pdf', content_type: 'application/pdf')

    get "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch('data')).to include('ic_copy_uploaded' => true)
    expect(response.body).not_to include('signed_id', 'blob_url', 'token')
  end

  it 'reuses an IC copy only from a booking owned by the verified event session' do
    price = create(:exhibitor_booth_price, event: event, price: 100)
    source = create(:exhibitor_kit, event_vendor: exhibitor)
    source.ic_copy.attach(io: StringIO.new('identity'), filename: 'ic.pdf', content_type: 'application/pdf')

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: { exhibitor_booth_price_id: price.id, company_name: 'Acme', pic_full_name: 'Owner',
                 pic_contact_number: '0123456789', indemnity_signed: true, source_booking_public_id: source.public_id,
                reuse_ic_copy: true },
      headers: headers.merge('Idempotency-Key' => 'reused-ic')

    expect(response).to have_http_status(:created)
    expect(exhibitor.exhibitor_kits.find_by!(idempotency_key: 'reused-ic').ic_copy.blob).to eq(source.ic_copy.blob)

    foreign = create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event))
    foreign.ic_copy.attach(io: StringIO.new('foreign'), filename: 'foreign.pdf', content_type: 'application/pdf')
    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: { exhibitor_booth_price_id: price.id, company_name: 'Acme', pic_full_name: 'Owner',
                 pic_contact_number: '0123456789', indemnity_signed: true, source_booking_public_id: foreign.public_id,
                reuse_ic_copy: true },
      headers: headers.merge('Idempotency-Key' => 'foreign-ic')

    expect(response).to have_http_status(:not_found)
    expect(exhibitor.exhibitor_kits.find_by(idempotency_key: 'foreign-ic')).to be_nil
  end

  it 'rejects reuse when the owned source booking has no IC copy' do
    price = create(:exhibitor_booth_price, event: event, price: 100)
    source = create(:exhibitor_kit, event_vendor: exhibitor)

    post "/v1/public/events/#{event.slug}/exhibitor_bookings",
      params: { exhibitor_booth_price_id: price.id, company_name: 'Acme', pic_full_name: 'Owner',
                 pic_contact_number: '0123456789', indemnity_signed: true, source_booking_public_id: source.public_id,
                reuse_ic_copy: true },
      headers: headers.merge('Idempotency-Key' => 'missing-source-ic')

    expect(response).to have_http_status(:unprocessable_content)
    expect(exhibitor.exhibitor_kits.find_by(idempotency_key: 'missing-source-ic')).to be_nil
  end

  it 'lists limited owned summaries and hides foreign UUIDs' do
    owned = create(:exhibitor_kit, event_vendor: exhibitor)
    foreign = create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event))

    get "/v1/public/events/#{event.slug}/exhibitor_bookings", headers: headers
    expect(response.parsed_body.dig('data', 0)).not_to include('company_address', 'pic_contact_number')

    get "/v1/public/events/#{event.slug}/exhibitor_bookings/#{foreign.public_id}", headers: headers
    expect(response).to have_http_status(:not_found)
    get "/v1/public/events/#{event.slug}/exhibitor_bookings/#{owned.public_id}", headers: headers
    expect(response).to have_http_status(:ok)
  end

  it 'matches owned bookings case-insensitively' do
    vendor.update_column(:email, 'OWNER@EXAMPLE.COM')
    owned = create(:exhibitor_kit, event_vendor: exhibitor)

    get "/v1/public/events/#{event.slug}/exhibitor_bookings/#{owned.public_id}", headers: headers

    expect(response).to have_http_status(:ok)
  end

  it 'reports whether a booth number is already assigned in the event' do
    create(:exhibitor_kit, event_vendor: exhibitor, booth_number: 'A-15')

    get "/v1/public/events/#{event.slug}/exhibitor_booth_number_availability",
      params: { booth_number: ' a-15 ' }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      'success' => true,
      'data' => { 'available' => false, 'message' => 'Booth number a-15 is already assigned' }
    )
  end

  it 'requires idempotency key and exact optimistic version for updates' do
    kit = create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :unpaid)
    patch "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}",
      params: { company_name: 'Updated' }, headers: headers.merge('If-Match' => kit.lock_version.to_s)
    expect(response).to have_http_status(:ok)

    kit.reload.update!(payment_status: :paid, booking_status: :paid)
    patch "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}",
      params: { company_name: 'Forbidden' }, headers: headers.merge('If-Match' => kit.lock_version.to_s)
    expect(response).to have_http_status(:forbidden)
  end

  it 'requires a valid If-Match and returns precondition failed for a stale version' do
    kit = create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :unpaid)

    patch "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}",
      params: { company_name: 'Updated' }, headers: headers
    expect(response).to have_http_status(:precondition_required)

    patch "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}",
      params: { company_name: 'Updated' }, headers: headers.merge('If-Match' => 'invalid')
    expect(response).to have_http_status(:precondition_required)

    kit.update!(company_name: 'Concurrent change')
    patch "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}",
      params: { company_name: 'Updated' }, headers: headers.merge('If-Match' => '0')
    expect(response).to have_http_status(:precondition_failed)
  end

  it 'ignores unsupported fields on PATCH' do
    kit = create(:exhibitor_kit, event_vendor: exhibitor, payment_status: :unpaid,
      booth_quantity: 1, custom_fields_data: { 'payment_option' => 'later' })
    voucher = create(:exhibitor_voucher, event: event)

    patch "/v1/public/events/#{event.slug}/exhibitor_bookings/#{kit.public_id}",
      params: { booth_quantity: 8, payment_option: 'now', custom_fields_data: { unsafe: true },
                ic_copy_signed_id: 'bad', voucher_code: voucher.code, company_name: 'Updated' },
      headers: headers.merge('If-Match' => kit.lock_version.to_s)

    expect(response).to have_http_status(:ok)
    expect(kit.reload).to have_attributes(company_name: 'Updated', booth_quantity: 1,
      custom_fields_data: { 'payment_option' => 'later' })
    expect(voucher.reload).to be_active
  end
end
