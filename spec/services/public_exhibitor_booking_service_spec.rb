require 'rails_helper'

RSpec.describe PublicExhibitorBookingService do
  let(:event) { create(:event, status: :published, use_exhibitor_kit: true) }
  let(:vendor) { create(:user, :vendor, email: 'vendor@example.com') }
  let(:exhibitor) { create(:exhibitor, event: event, vendor: vendor) }
  let(:access) do
    PublicExhibitorAccessSession.create!(event: event, normalized_email: vendor.email,
      challenge_digest: SecureRandom.hex(32), challenge_expires_at: 1.minute.ago,
      session_digest: SecureRandom.hex(32), expires_at: 1.hour.from_now)
  end
  let(:zone) { create(:exhibitor_zone, event: event, quota: 2) }
  let(:price) { create(:exhibitor_booth_price, event: event, exhibitor_zone: zone, quota: 2, price: 100) }
  let(:attributes) do
    { exhibitor_booth_price_id: price.id, company_name: 'Acme', pic_full_name: 'Pat',
      pic_contact_number: '123', payment_option: 'later' }
  end
  let(:deliveries) { [] }
  let(:welcome_deliveries) { deliveries.select { |delivery| delivery[:mailer_action] == 'welcome' } }

  before do
    allow(EmailDelivery::AuditedDelivery).to receive(:deliver_later) { |delivery| deliveries << delivery }
    allow(EmailDelivery::AuditedDelivery).to receive(:deliver_now) { |delivery| deliveries << delivery }
  end

  it 'emails login credentials only after creating a new user and booking' do
    access.update!(normalized_email: 'new.vendor@example.com')

    result = described_class.call(event: event, access: access, idempotency_key: 'new-user', attributes: attributes)
    user = User.find_by!(email: access.normalized_email)
    password = welcome_deliveries.dig(0, :args, 1)

    expect(result.idempotent_replay).to be(false)
    expect(welcome_deliveries.first).to include(
      mailer_name: 'PublicExhibitorWelcomeMailer', mailer_action: 'welcome',
      args: [user.email, password], related: user, metadata: {}, dedupe: true
    )
    expect(password).to match(/\ASabah-[0-9A-F]{8}!\z/)
    expect(user.authenticate(password)).to eq(user)
    expect(user.password_digest).not_to include(password)
    expect(user.attributes.to_json).not_to include(password)
  end

  it 'does not email or persist a new user when booking rolls back' do
    access.update!(normalized_email: 'rollback@example.com')
    allow_any_instance_of(ExhibitorIcCopyAttacher).to receive(:call).and_raise(ActiveRecord::RecordInvalid)

    expect {
      described_class.call(event: event, access: access, idempotency_key: 'rollback', attributes: attributes)
    }.to raise_error(ActiveRecord::RecordInvalid)

    expect(User.find_by(email: access.normalized_email)).to be_nil
    expect(welcome_deliveries).to be_empty
  end

  it 'does not email credentials to an existing user' do
    exhibitor

    described_class.call(event: event, access: access, idempotency_key: 'existing-user', attributes: attributes)

    expect(welcome_deliveries).to be_empty
  end

  it 'does not email credentials again on idempotent replay' do
    access.update!(normalized_email: 'replay@example.com')
    described_class.call(event: event, access: access, idempotency_key: 'replay', attributes: attributes)

    expect {
      described_class.call(event: event, access: access, idempotency_key: 'replay', attributes: attributes)
    }.not_to change(welcome_deliveries, :count)
    expect(welcome_deliveries.count).to eq(1)
  end

  it 'replays one key but creates sibling kits for different keys' do
    exhibitor
    first = described_class.call(event: event, access: access, idempotency_key: 'key-1', attributes: attributes)
    replay = described_class.call(event: event, access: access, idempotency_key: 'key-1', attributes: attributes)
    second = described_class.call(event: event, access: access, idempotency_key: 'key-2', attributes: attributes)

    expect(replay).to have_attributes(kit: first.kit, idempotent_replay: true)
    expect(second.kit).not_to eq(first.kit)
    expect(exhibitor.exhibitor_kits.count).to eq(2)
  end

  it 'rejects reuse of a key with a different normalized payload' do
    exhibitor
    described_class.call(event: event, access: access, idempotency_key: 'key-1', attributes: attributes)
    expect {
      described_class.call(event: event, access: access, idempotency_key: 'key-1',
                           attributes: attributes.merge(company_name: 'Other'))
    }.to raise_error(described_class::IdempotencyConflict)
  end

  it 'does not exceed booth capacity' do
    price.update!(quota: 1)
    exhibitor
    described_class.call(event: event, access: access, idempotency_key: 'key-1', attributes: attributes)
    expect {
      described_class.call(event: event, access: access, idempotency_key: 'key-2', attributes: attributes)
    }.to raise_error(described_class::SoldOut)
  end

  it 'forces public bookings to one booth and snapshots one current price' do
    exhibitor
    result = described_class.call(event: event, access: access, idempotency_key: 'key-1',
      attributes: attributes.merge(booth_quantity: 9))

    expect(result.kit).to have_attributes(booth_quantity: 1, price_snapshot: 100, amount_paid: 100)
  end

  it 'uses a replacement upload instead of a requested source IC copy' do
    exhibitor
    source = create(:exhibitor_kit, event_vendor: exhibitor)
    source.ic_copy.attach(io: StringIO.new('old identity'), filename: 'old.pdf', content_type: 'application/pdf')
    replacement = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('new identity'), filename: 'new.pdf',
      content_type: 'application/pdf', metadata: { document_key: 'exhibitor_ic_copy', event_id: event.id })

    result = described_class.call(event: event, access: access, idempotency_key: 'replacement',
      attributes: attributes.merge(source_booking_public_id: source.public_id, reuse_ic_copy: true,
        ic_copy_signed_id: replacement.signed_id))

    expect(result.kit.ic_copy.blob).to eq(replacement)
  end

  it 'attaches the existing blob from an owned source booking' do
    exhibitor
    source = create(:exhibitor_kit, event_vendor: exhibitor)
    source.ic_copy.attach(io: StringIO.new('identity'), filename: 'ic.pdf', content_type: 'application/pdf')

    result = described_class.call(event: event, access: access, idempotency_key: 'reuse',
      attributes: attributes.merge(source_booking_public_id: source.public_id, reuse_ic_copy: true))

    expect(result.kit.ic_copy.blob).to eq(source.ic_copy.blob)
  end
end
