require 'rails_helper'

RSpec.describe EventVendorBatchService, type: :service do
  describe '.create' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:organizer) { create(:user, :organizer) }
    let(:vendor) { create(:user, :vendor) }
    let(:first_zone) { create(:exhibitor_zone, event:, zone: 'zone_a') }
    let(:second_zone) { create(:exhibitor_zone, event:, zone: 'zone_b') }
    let(:first_booth_price) do
      create(:exhibitor_booth_price, event:, exhibitor_zone: first_zone, booth_type: 'shell_scheme')
    end
    let(:second_booth_price) do
      create(:exhibitor_booth_price, event:, exhibitor_zone: second_zone, booth_type: 'raw_space')
    end
    let!(:first_booth) do
      create(:exhibitor_booth, event:, exhibitor_booth_price: first_booth_price, number: 'A101', status: :available)
    end
    let!(:second_booth) do
      create(:exhibitor_booth, event:, exhibitor_booth_price: second_booth_price, number: 'A102', status: :available)
    end
    let(:batch_params) do
      {
        vendor_id: vendor.id,
        redirect_url: 'https://example.com/vendor',
        poster_url: 'https://example.com/poster.jpg',
        qr_url: 'https://example.com/qr.png',
        exhibitor: {
          company_name: 'Acme Sdn Bhd',
          name_on_fascia: 'Acme Sdn Bhd',
          pic_full_name: 'Ada Lovelace',
          pic_contact_number: '+60123456789',
          pic_email_address: 'ada@example.com',
          special_requirements: 'Near the entrance'
        },
        booths: [
          {
            booth_type: first_booth_price.booth_type,
            exhibitor_booth_price_id: first_booth_price.id,
            exhibitor_package_id: nil,
            booth_number: first_booth.number,
            voucher_code: nil
          },
          {
            booth_type: second_booth_price.booth_type,
            exhibitor_booth_price_id: second_booth_price.id,
            exhibitor_package_id: nil,
            booth_number: second_booth.number,
            voucher_code: nil
          }
        ]
      }
    end
    let(:booth_price) { first_booth_price }
    let(:package) { create(:exhibitor_package, event:, exhibitor_booth_price: booth_price, price: 1200) }
    let(:other_package) do
      create(:exhibitor_package, event:, exhibitor_booth_price: second_booth_price, price: 1300)
    end
    let(:valid_booth) do
      { exhibitor_booth_price_id: booth_price.id, booth_number: 'A101' }
    end
    let(:invalid_package_booth) do
      { exhibitor_booth_price_id: booth_price.id, exhibitor_package_id: other_package.id,
        booth_number: 'A102' }
    end
    let(:valid_priced_booth) { valid_booth.merge(booth_type: booth_price.booth_type) }

    it 'creates one quantity-one kit per booth in one event-vendor assignment' do
      result = described_class.create(
        event: event,
        current_user: organizer,
        idempotency_key: 'admin-batch-1',
        params: batch_params
      )

      expect(result).to be_success
      expect(result.data).to be_a(Exhibitor)

      kits = result.data.exhibitor_kits.reload
      expect(kits.size).to eq(2)
      expect(kits.pluck(:booth_number)).to contain_exactly('A101', 'A102')
      expect(kits.pluck(:booth_quantity)).to all(eq(1))
      expect(kits.map { |kit| kit.custom_fields_data['booking_batch_id'] }.uniq.size).to eq(1)
      expect(kits.pluck(:name_on_fascia)).to all(eq('Acme Sdn Bhd'))
    end

    it 'rejects an empty booths array' do
      result = described_class.create(
        event:, current_user: organizer, idempotency_key: 'admin-batch-empty',
        params: batch_params.merge(booths: [])
      )

      expect(result).to be_failure
      expect(event.event_vendors.where(vendor:)).to be_empty
    end

    it 'rolls back every row when a package belongs to another booth price' do
      result = described_class.create(
        event: event,
        current_user: organizer,
        idempotency_key: 'admin-batch-mismatch',
        params: batch_params.merge(booths: [valid_priced_booth, invalid_package_booth.merge(booth_type: booth_price.booth_type)])
      )

      expect(result).not_to be_success
      expect(event.reload.event_vendors.where(vendor: vendor)).to be_empty
      expect(ExhibitorKit.where(booth_number: %w[A101 A102])).to be_empty
    end

    it 'rejects a missing inventory booth number' do
      result = described_class.create(
        event:, current_user: organizer, idempotency_key: 'admin-batch-missing-booth',
        params: batch_params.merge(booths: [valid_priced_booth.merge(booth_number: 'A999')])
      )

      expect(result).to be_failure
      expect(event.event_vendors.where(vendor:)).to be_empty
    end

    it 'rejects an inventory booth that belongs to a different booth price' do
      result = described_class.create(
        event:, current_user: organizer, idempotency_key: 'admin-batch-booth-mismatch',
        params: batch_params.merge(booths: [valid_priced_booth.merge(booth_number: 'A102')])
      )

      expect(result).to be_failure
      expect(event.event_vendors.where(vendor:)).to be_empty
    end

    it 'rolls back all booths when one selected inventory booth is unavailable' do
      second_booth.update!(status: :reserved)

      expect {
        described_class.create(event:, current_user: organizer,
                               idempotency_key: 'admin-batch-sold-out', params: batch_params)
      }.not_to change(ExhibitorKit, :count)
    end

    it 'rejects duplicate normalized inventory booth selections without reserving kits' do
      create(:exhibitor_booth, event:, exhibitor_booth_price: first_booth_price,
                               number: 'A103', status: :available)
      duplicate_params = batch_params.merge(booths: [
        valid_priced_booth,
        valid_priced_booth.merge(booth_number: ' A101 ')
      ])
      result = nil

      expect {
        result = described_class.create(
          event:, current_user: organizer, idempotency_key: 'admin-batch-duplicate-inventory',
          params: duplicate_params
        )
      }.not_to change(ExhibitorKit, :count)

      expect(result).to be_failure
      expect(result.errors).to include('An inventory booth can only be selected once')
      expect(first_booth.reload).to be_available
      expect(first_booth.exhibitor_kit).to be_nil
    end

    it 'rejects a sold-out non-inventory quota' do
      quota_price = create(:exhibitor_booth_price, event:, exhibitor_zone: nil, quota: 1)
      existing_exhibitor = create(:exhibitor, event:, vendor: create(:user, :vendor))
      create(:exhibitor_kit, event_vendor: existing_exhibitor, exhibitor_booth_price: quota_price,
                             booth_quantity: 1, booking_status: :active)

      result = described_class.create(
        event:, current_user: organizer, idempotency_key: 'admin-batch-quota',
        params: batch_params.merge(booths: [{ exhibitor_booth_price_id: quota_price.id,
                                              booth_type: quota_price.booth_type }])
      )

      expect(result).to be_failure
      expect(event.event_vendors.where(vendor:)).to be_empty
    end

    it 'rolls back the batch for an invalid voucher' do
      result = described_class.create(
        event:, current_user: organizer, idempotency_key: 'admin-batch-invalid-voucher',
        params: batch_params.merge(booths: [valid_priced_booth.merge(voucher_code: 'NOT-A-VOUCHER')])
      )

      expect(result).to be_failure
      expect(result.errors).to include(ExhibitorVoucherRedemption::INVALID_MESSAGE)
      expect(event.event_vendors.where(vendor:)).to be_empty
    end

    it 'uses the supplied booth type without price processing for a no-price row' do
      result = described_class.create(
        event:, current_user: organizer, idempotency_key: 'admin-batch-fallback',
        params: batch_params.merge(booths: [{ booth_type: '  custom booth  ', booth_number: ' C101 ' }])
      )

      expect(result).to be_success
      kit = result.data.exhibitor_kits.sole
      expect(kit).to have_attributes(
        booth_type: 'custom booth',
        booth_number: 'C101',
        exhibitor_booth_price_id: nil,
        exhibitor_package_id: nil,
        amount_paid: nil
      )
    end

    it 'derives the package price and redeems a shared voucher once against its first kit' do
      voucher = create(:exhibitor_voucher, :fixed_amount, event:, code: 'BATCH500')
      result = described_class.create(
        event:, current_user: organizer, idempotency_key: 'admin-batch-voucher',
        params: batch_params.merge(booths: [
          valid_booth.merge(exhibitor_package_id: package.id, voucher_code: voucher.code),
          { exhibitor_booth_price_id: second_booth_price.id, booth_number: 'A102', voucher_code: voucher.code }
        ])
      )

      expect(result).to be_success
      expect(result.data.exhibitor_kits.pluck(:amount_paid)).to contain_exactly(700, 1000)
      expect(voucher.reload.redeemed_by_exhibitor_kit).to be_in(result.data.exhibitor_kits)
    end

    it 'replays an identical normalized batch without creating duplicate kits' do
      first = described_class.create(event:, current_user: organizer,
                                     idempotency_key: 'admin-retry', params: batch_params)
      normalized_retry_params = batch_params.deep_dup
      normalized_retry_params[:booths][0][:booth_number] = ' A101 '
      normalized_retry_params[:exhibitor][:company_name] = ' Acme Sdn Bhd '
      second = described_class.create(event:, current_user: organizer,
                                      idempotency_key: 'admin-retry', params: normalized_retry_params)

      expect(second).to be_success
      expect(second).to be_idempotent_replay
      expect(second.data.id).to eq(first.data.id)
      expect(second.data.exhibitor_kits.count).to eq(2)
      expect(ExhibitorKit.where(event_vendor_id: first.data.id).count).to eq(2)
    end

    it 'does not replay an existing batch for an unauthorized caller' do
      first = described_class.create(event:, current_user: organizer,
                                     idempotency_key: 'admin-unauthorized-retry', params: batch_params)
      unauthorized_user = create(:user, :member)

      replay = described_class.create(event:, current_user: unauthorized_user,
                                      idempotency_key: 'admin-unauthorized-retry', params: batch_params)

      expect(first).to be_success
      expect(replay).to be_failure
      expect(replay).not_to be_idempotent_replay
      expect(replay.data).to be_nil
      expect(replay.errors).to include('not allowed to create this exhibitor')
    end

    it 'returns a conflict for a different normalized payload using an existing key' do
      first = described_class.create(event:, current_user: organizer,
                                     idempotency_key: 'admin-conflict', params: batch_params)
      changed_params = batch_params.deep_dup
      changed_params[:booths][0][:booth_number] = 'A999'

      second = described_class.create(event:, current_user: organizer,
                                      idempotency_key: 'admin-conflict', params: changed_params)

      expect(first).to be_success
      expect(second).to be_failure
      expect(second.errors).to include('Idempotency key conflicts with a different batch')
      expect(ExhibitorKit.where(event_vendor_id: first.data.id).count).to eq(2)
    end

    it 're-checks idempotency after the event lock when a batch appears after the first lookup' do
      first = described_class.create(event:, current_user: organizer,
                                     idempotency_key: 'admin-locked-retry', params: batch_params)
      service = described_class.new(event:, current_user: organizer,
                                    idempotency_key: 'admin-locked-retry', params: batch_params)

      expect(service).to receive(:existing_batch).with(vendor).ordered.and_return(nil)
      expect(event).to receive(:lock!).ordered.and_call_original
      expect(service).to receive(:existing_batch).with(vendor).ordered.and_call_original

      result = service.call

      expect(first).to be_success
      expect(result).to be_success
      expect(result).to be_idempotent_replay
      expect(result.data.id).to eq(first.data.id)
      expect(ExhibitorKit.where(event_vendor_id: first.data.id).count).to eq(2)
    end
  end
end
