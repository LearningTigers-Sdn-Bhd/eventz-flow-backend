require 'rails_helper'

RSpec.describe ExhibitorKitService, type: :service do
  describe '#create with a package' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:organizer) { create(:user, :organizer) }
    let(:exhibitor) { create(:exhibitor, event: event) }
    let(:base_kit_params) { attributes_for(:exhibitor_kit).merge(event_vendor_id: exhibitor.id) }
    let(:booth_price) { create(:exhibitor_booth_price, event: event, price: 5000.0) }
    let!(:package) { create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, price: 7000.0) }

    it 'prices the kit from the package' do
      params = ActionController::Parameters.new(exhibitor_kit: base_kit_params.merge(
        exhibitor_booth_price_id: booth_price.id, exhibitor_package_id: package.id
      ))
      result = described_class.new(user: organizer, event: event, params: params).create

      expect(result).to be_success
      expect(result.data.exhibitor_package_id).to eq(package.id)
      expect(result.data.price_snapshot).to eq(7000.0)
      expect(result.data.amount_paid).to eq(7000.0)
    end

    it 'fails when the package quota is exhausted' do
      package.update!(quota: 0)

      params = ActionController::Parameters.new(exhibitor_kit: base_kit_params.merge(
        exhibitor_booth_price_id: booth_price.id, exhibitor_package_id: package.id
      ))
      result = described_class.new(user: organizer, event: event, params: params).create

      expect(result).not_to be_success
      expect(result.errors).to eq('Booth capacity is sold out')
    end
  end

  describe '#update' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:user) { create(:user, :organizer) }
    let(:exhibitor_kit) do
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event),
        payment_status: :unpaid, booking_status: :active, reservation_expires_at: 1.day.from_now)
    end
    let!(:registration_payment) do
      create(:exhibitor_registration_payment, exhibitor_kit: exhibitor_kit, status: 'submitted')
    end
    let(:params) do
      ActionController::Parameters.new(
        exhibitor_kit: { payment_status: 'paid', amount_paid: '1500.00', payment_note: 'Bank transfer verified' }
      )
    end

    it 'lets an organizer approve a registration payment' do
      result = described_class.new(user: user, event: event, params: params).update(exhibitor_kit)

      expect(result).to be_success
      expect(exhibitor_kit.reload).to have_attributes(
        payment_status: 'paid',
        booking_status: 'paid',
        reservation_expires_at: nil,
        amount_paid: 1500,
        payment_note: 'Bank transfer verified'
      )
      expect(registration_payment.reload).to have_attributes(
        status: 'paid',
        payment_method: 'manual_bank_transfer'
      )
      expect(registration_payment.paid_at).to be_present
    end
  end

  describe '#create' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:user) { create(:user, :vendor) }
    let(:exhibitor) { create(:exhibitor, event: event, vendor: user) }
    let(:zone) { create(:exhibitor_zone, event: event, quota: 3) }
    let(:booth_price) do
      create(:exhibitor_booth_price, event: event, exhibitor_zone: zone, quota: 3, price: 125)
    end
    let!(:existing_kit) { create(:exhibitor_kit, event_vendor: exhibitor) }
    let(:params) do
      ActionController::Parameters.new(
        exhibitor_kit: attributes_for(:exhibitor_kit).merge(
          event_vendor_id: exhibitor.id,
          exhibitor_booth_price_id: booth_price.id,
          booth_quantity: 2,
          amount_paid: 1,
          payment_status: 'paid',
          booking_status: 'cancelled',
          price_snapshot: 1
        )
      )
    end

    it 'explicitly creates an additional kit in the vendor collection' do
      result = described_class.new(user: user, event: event, params: params).create

      expect(result).to be_success
      expect(exhibitor.reload.exhibitor_kits).to contain_exactly(existing_kit, result.data)
      expect(result.data).to have_attributes(
        exhibitor_booth_price: booth_price,
        booth_type: booth_price.booth_type,
        booth_quantity: 1,
        amount_paid: 125,
        price_snapshot: 125,
        payment_status: 'unpaid',
        booking_status: 'active',
        reservation_expires_at: nil
      )
    end

    it 'rejects a quantity that exceeds booth capacity' do
      booth_price.update!(quota: 0)

      result = described_class.new(user: user, event: event, params: params).create

      expect(result).not_to be_success
      expect(result.status).to eq(:unprocessable_content)
      expect(exhibitor.reload.exhibitor_kits).to contain_exactly(existing_kit)
    end

    it 'does not count cancelled or expired reservations against capacity' do
      booth_price.update!(quota: 1)
      create(:exhibitor_kit, event_vendor: exhibitor, exhibitor_booth_price: booth_price,
        booth_quantity: 2, booking_status: :cancelled)
      create(:exhibitor_kit, event_vendor: exhibitor, exhibitor_booth_price: booth_price,
        booth_quantity: 2, booking_status: :active, reservation_expires_at: 1.minute.ago)

      result = described_class.new(user: user, event: event, params: params).create

      expect(result).to be_success
      expect(result.data.booth_quantity).to eq(1)
    end

    it 'ignores a non-positive quantity and creates exactly one booth' do
      params[:exhibitor_kit][:booth_quantity] = 0

      result = described_class.new(user: user, event: event, params: params).create

      expect(result).to be_success
      expect(result.data).to have_attributes(booth_quantity: 1, amount_paid: 125, price_snapshot: 125)
    end

    it 'returns not found for a vendor from another event' do
      foreign_event = create(:event, use_exhibitor_kit: true)
      foreign_exhibitor = create(:exhibitor, event: foreign_event, vendor: user)
      params[:exhibitor_kit][:event_vendor_id] = foreign_exhibitor.id

      result = described_class.new(user: user, event: event, params: params).create

      expect(result.status).to eq(:not_found)
      expect(foreign_exhibitor.reload.exhibitor_kits).to be_empty
    end
  end

  describe '#update changing booth price / package / voucher' do
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:user) { create(:user, :organizer) }
    let(:old_booth_price) { create(:exhibitor_booth_price, event: event, price: 1500.0, exhibitor_zone: nil) }
    let(:new_booth_price) { create(:exhibitor_booth_price, event: event, price: 2000.0, exhibitor_zone: nil) }
    let(:exhibitor_kit) do
      create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event),
        exhibitor_booth_price: old_booth_price, price_snapshot: 1500.0, amount_paid: 1500.0,
        payment_status: :unpaid, booking_status: :active)
    end

    def update_with(attrs)
      params = ActionController::Parameters.new(exhibitor_kit: attrs)
      described_class.new(user: user, event: event, params: params).update(exhibitor_kit)
    end

    it 'recomputes price_snapshot and amount_paid for the new booth price' do
      result = update_with(exhibitor_booth_price_id: new_booth_price.id)

      expect(result).to be_success
      expect(exhibitor_kit.reload).to have_attributes(
        exhibitor_booth_price_id: new_booth_price.id,
        booth_type: new_booth_price.booth_type,
        price_snapshot: 2000.0,
        amount_paid: 2000.0
      )
    end

    it 'rejects the change once the kit is settled' do
      exhibitor_kit.update!(payment_status: :paid)

      result = update_with(exhibitor_booth_price_id: new_booth_price.id)

      expect(result).not_to be_success
      expect(result.status).to eq(:unprocessable_content)
      expect(exhibitor_kit.reload.exhibitor_booth_price_id).to eq(old_booth_price.id)
    end

    it 'rejects a new booth price with no remaining capacity' do
      new_booth_price.update!(quota: 0)

      result = update_with(exhibitor_booth_price_id: new_booth_price.id)

      expect(result).not_to be_success
      expect(result.errors).to eq('Booth capacity is sold out')
      expect(exhibitor_kit.reload.exhibitor_booth_price_id).to eq(old_booth_price.id)
    end

    it 'releases a previously assigned booth when the booth price changes' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: old_booth_price,
        exhibitor_kit: exhibitor_kit, status: :booked)
      exhibitor_kit.update!(booth_number: booth.number)

      result = update_with(exhibitor_booth_price_id: new_booth_price.id)

      expect(result).to be_success
      expect(booth.reload).to have_attributes(status: 'available', exhibitor_kit_id: nil)
      expect(exhibitor_kit.reload.booth_number).to be_nil
    end

    it 'rejects a package that does not belong to the selected booth price' do
      mismatched_package = create(:exhibitor_package, event: event,
        exhibitor_booth_price: create(:exhibitor_booth_price, event: event, exhibitor_zone: nil))

      result = update_with(exhibitor_booth_price_id: new_booth_price.id,
        exhibitor_package_id: mismatched_package.id)

      expect(result).not_to be_success
      expect(result.errors).to eq('Booth price or package not found')
    end

    it 'prices from the package when one is selected' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: new_booth_price, price: 3200.0)

      result = update_with(exhibitor_booth_price_id: new_booth_price.id, exhibitor_package_id: package.id)

      expect(result).to be_success
      expect(exhibitor_kit.reload).to have_attributes(
        exhibitor_package_id: package.id,
        price_snapshot: 3200.0,
        amount_paid: 3200.0
      )
    end

    it 'releases the old voucher and redeems the new one when the voucher code changes' do
      old_voucher = create(:exhibitor_voucher, :redeemed, event: event, redeemed_by_exhibitor_kit: exhibitor_kit)
      new_voucher = create(:exhibitor_voucher, :fixed_amount, event: event)

      result = update_with(voucher_code: new_voucher.code)

      expect(result).to be_success
      expect(old_voucher.reload).to have_attributes(status: 'active', redeemed_by_exhibitor_kit_id: nil)
      expect(new_voucher.reload).to have_attributes(status: 'redeemed', redeemed_by_exhibitor_kit_id: exhibitor_kit.id)
      expect(exhibitor_kit.reload.price_snapshot).to eq(1000.0) # 1500 - 500 fixed off
    end

    it 'returns the old voucher to the pool when the voucher code is cleared' do
      old_voucher = create(:exhibitor_voucher, :redeemed, event: event, redeemed_by_exhibitor_kit: exhibitor_kit)

      result = update_with(voucher_code: '')

      expect(result).to be_success
      expect(old_voucher.reload).to have_attributes(status: 'active', redeemed_by_exhibitor_kit_id: nil)
      expect(exhibitor_kit.reload.price_snapshot).to eq(1500.0)
    end

    it 'rejects an invalid voucher code' do
      result = update_with(voucher_code: 'DOES-NOT-EXIST')

      expect(result).not_to be_success
      expect(result.errors).to eq('Voucher code is invalid or already used')
      expect(exhibitor_kit.reload.price_snapshot).to eq(1500.0)
    end
  end
end
