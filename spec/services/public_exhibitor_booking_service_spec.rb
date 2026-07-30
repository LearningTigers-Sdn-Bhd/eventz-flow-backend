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
      pic_contact_number: '123', payment_option: 'later', indemnity_signed: true }
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
      args: [user.email, password, user.full_name], related: user, metadata: {}, dedupe: true
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

  it 'rejects a duplicate booth number within the event regardless of case or spaces' do
    exhibitor
    described_class.call(event: event, access: access, idempotency_key: 'key-1',
      attributes: attributes.merge(booth_number: 'A-15'))

    expect {
      described_class.call(event: event, access: access, idempotency_key: 'key-2',
        attributes: attributes.merge(booth_number: ' a-15 '))
    }.to raise_error(described_class::DuplicateBoothNumber)
  end

  it 'forces public bookings to one booth and snapshots one current price' do
    exhibitor
    result = described_class.call(event: event, access: access, idempotency_key: 'key-1',
      attributes: attributes.merge(booth_quantity: 9))

    expect(result.kit).to have_attributes(booth_quantity: 1, price_snapshot: 100, amount_paid: 100)
  end

  it 'persists accepted participation and indemnity agreement' do
    exhibitor
    result = described_class.call(event: event, access: access, idempotency_key: 'agreement',
      attributes: attributes.merge(indemnity_signed: true))

    expect(result.kit).to be_indemnity_signed
  end

  it 'rejects a booking without participation and indemnity agreement' do
    exhibitor

    expect {
      described_class.call(event: event, access: access, idempotency_key: 'missing-agreement',
        attributes: attributes.merge(indemnity_signed: false))
    }.to raise_error(described_class::AgreementRequired)
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

  describe 'reservation expiry' do
    it 'leaves the hold open when the event has no ttl configured' do
      event.update!(exhibitor_reservation_ttl_hours: nil)

      result = described_class.call(event: event, access: access, idempotency_key: 'ttl-nil',
        attributes: attributes)

      expect(result.kit.reservation_expires_at).to be_nil
    end

    it 'sets the hold from the event ttl when configured' do
      event.update!(exhibitor_reservation_ttl_hours: 48)

      result = described_class.call(event: event, access: access, idempotency_key: 'ttl-48',
        attributes: attributes)

      expect(result.kit.reservation_expires_at).to be_within(1.minute).of(48.hours.from_now)
    end

    it 'never sets a hold when paying now' do
      event.update!(exhibitor_reservation_ttl_hours: 48)

      result = described_class.call(event: event, access: access, idempotency_key: 'ttl-now',
        attributes: attributes.merge(payment_option: 'now'))

      expect(result.kit.reservation_expires_at).to be_nil
    end
  end

  describe 'booth inventory' do
    let!(:booth) { create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045') }
    let(:inventory_attributes) { attributes.merge(booth_number: 'S045') }

    it 'reserves the selected booth and snapshots its number on the kit' do
      result = described_class.call(event: event, access: access, idempotency_key: 'claim-1',
        attributes: inventory_attributes)

      expect(booth.reload).to have_attributes(status: 'reserved', exhibitor_kit_id: result.kit.id)
      expect(result.kit.booth_number).to eq('S045')
    end

    it 'accepts a number in any casing or padding' do
      described_class.call(event: event, access: access, idempotency_key: 'claim-2',
        attributes: attributes.merge(booth_number: ' s045 '))

      expect(booth.reload).to be_reserved
    end

    it 'requires a booth number when the price has inventory' do
      expect do
        described_class.call(event: event, access: access, idempotency_key: 'claim-3',
          attributes: attributes.merge(booth_number: nil))
      end.to raise_error(described_class::BoothNumberRequired)
    end

    it 'rejects a number that does not exist for the event' do
      expect do
        described_class.call(event: event, access: access, idempotency_key: 'claim-4',
          attributes: attributes.merge(booth_number: 'S999'))
      end.to raise_error(described_class::BoothNotFound)
    end

    it 'rejects a booth belonging to a different booth price' do
      other_price = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone)
      create(:exhibitor_booth, event: event, exhibitor_booth_price: other_price, number: 'K101')

      expect do
        described_class.call(event: event, access: access, idempotency_key: 'claim-5',
          attributes: attributes.merge(booth_number: 'K101'))
      end.to raise_error(described_class::BoothPriceMismatch)
    end

    it 'rejects a blocked booth' do
      booth.update!(status: :blocked)

      expect do
        described_class.call(event: event, access: access, idempotency_key: 'claim-6',
          attributes: inventory_attributes)
      end.to raise_error(described_class::BoothUnavailable)
    end

    it 'rejects a booth already held by a live booking' do
      described_class.call(event: event, access: access, idempotency_key: 'claim-7',
        attributes: inventory_attributes)

      expect do
        described_class.call(event: event, access: access, idempotency_key: 'claim-8',
          attributes: inventory_attributes)
      end.to raise_error(described_class::BoothUnavailable)
    end

    it 'lets a second exhibitor take over a booth whose hold lapsed' do
      event.update!(exhibitor_reservation_ttl_hours: 48)
      first = described_class.call(event: event, access: access, idempotency_key: 'claim-9',
        attributes: inventory_attributes)
      first.kit.update!(reservation_expires_at: 1.hour.ago)

      second = described_class.call(event: event, access: access, idempotency_key: 'claim-10',
        attributes: inventory_attributes)

      expect(booth.reload.exhibitor_kit_id).to eq(second.kit.id)
    end

    describe 'amending a booking' do
      let!(:other_booth) do
        create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S046')
      end

      def booking
        described_class.call(event: event, access: access, idempotency_key: 'amend-src',
          attributes: inventory_attributes).kit
      end

      it 'moves the hold to another booth in the same price' do
        kit = booking

        described_class.new(event: event, access: access).update(
          kit: kit, expected_lock_version: kit.lock_version, attributes: { booth_number: 'S046' }
        )

        expect(booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
        expect(other_booth.reload).to have_attributes(status: 'reserved', exhibitor_kit_id: kit.id)
        expect(kit.reload.booth_number).to eq('S046')
      end

      it 'moves the hold when the booth price changes' do
        kit = booking
        premium = create(:exhibitor_booth_price, event: event, exhibitor_zone: zone, price: 200)
        premium_booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: premium,
          number: 'S200')

        described_class.new(event: event, access: access).update(
          kit: kit, expected_lock_version: kit.lock_version,
          attributes: { exhibitor_booth_price_id: premium.id, booth_number: 'S200' }
        )

        expect(booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
        expect(premium_booth.reload).to have_attributes(status: 'reserved', exhibitor_kit_id: kit.id)
        expect(kit.reload.price_snapshot).to eq(200)
      end

      it 'keeps the original hold when the new booth is unavailable' do
        kit = booking
        other_booth.update!(status: :blocked)

        expect do
          described_class.new(event: event, access: access).update(
            kit: kit, expected_lock_version: kit.lock_version, attributes: { booth_number: 'S046' }
          )
        end.to raise_error(described_class::BoothUnavailable)

        expect(booth.reload).to have_attributes(status: 'reserved', exhibitor_kit_id: kit.id)
      end
    end
  end

  describe 'concurrent claims' do
    let!(:booth) { create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045') }

    it 'lets exactly one of two racing registrations take the booth' do
      results = Queue.new
      errors = Queue.new

      threads = Array.new(2) do |index|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            results << described_class.call(event: event, access: access,
              idempotency_key: "race-#{index}",
              attributes: attributes.merge(booth_number: 'S045'))
          end
        rescue described_class::BoothUnavailable => e
          errors << e
        end
      end
      threads.each(&:join)

      expect(results.size).to eq(1)
      expect(errors.size).to eq(1)
      expect(booth.reload.exhibitor_kit_id).to eq(results.pop.kit.id)
    end
  end
end
