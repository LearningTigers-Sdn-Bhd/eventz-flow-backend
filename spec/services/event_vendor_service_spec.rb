# spec/services/event_vendor_service_spec.rb

require 'rails_helper'

RSpec.describe EventVendorService, type: :service do
  describe '.enrich_exhibitor_kit_attributes with a package' do
    let(:event) { create(:event) }
    let(:booth_price) { create(:exhibitor_booth_price, event: event, price: 5000.0) }
    let!(:package) { create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, price: 7000.0) }

    it 'prices from the package when one is supplied' do
      attrs = described_class.enrich_exhibitor_kit_attributes(event, {
        exhibitor_booth_price_id: booth_price.id, exhibitor_package_id: package.id
      })

      expect(attrs[:amount_paid]).to eq(7000.0)
      expect(attrs[:exhibitor_package_id]).to eq(package.id)
    end

    it 'multiplies the package price by booth quantity' do
      attrs = described_class.enrich_exhibitor_kit_attributes(event, {
        exhibitor_booth_price_id: booth_price.id, exhibitor_package_id: package.id, booth_quantity: 2
      })

      expect(attrs[:amount_paid]).to eq(14_000.0)
    end

    it 'drops a package attached to a different booth price' do
      other = create(:exhibitor_package, event: event,
        exhibitor_booth_price: create(:exhibitor_booth_price, event: event,
          exhibitor_zone: booth_price.exhibitor_zone))

      attrs = described_class.enrich_exhibitor_kit_attributes(event, {
        exhibitor_booth_price_id: booth_price.id, exhibitor_package_id: other.id
      })

      expect(attrs[:exhibitor_package_id]).to be_nil
      expect(attrs[:amount_paid]).to eq(5000.0)
    end

    it 'still prices from the booth price when no package is supplied' do
      attrs = described_class.enrich_exhibitor_kit_attributes(event, {
        exhibitor_booth_price_id: booth_price.id
      })

      expect(attrs[:amount_paid]).to eq(5000.0)
    end
  end

  describe '.determine_vendor_type' do
    context 'when event.use_ticket is true' do
      let(:event) { create(:event, use_ticket: true) }

      it 'returns Exhibitor' do
        expect(EventVendorService.determine_vendor_type(event)).to eq('Exhibitor')
      end
    end

    context 'when event.use_ticket is false' do
      let(:event) { create(:event, use_ticket: false) }

      it 'returns Merchant' do
        expect(EventVendorService.determine_vendor_type(event)).to eq('Merchant')
      end
    end
  end



  describe '.create' do
    let(:current_user) { create(:user, :organizer) }
    let(:event) { create(:event, use_ticket: true) }

    it 'locks the event for non-voucher assignments too' do
      vendor = create(:user, :vendor)
      expect(event).to receive(:lock!).and_call_original

      result = described_class.create(
        event: event,
        params: { vendor_id: vendor.id },
        current_user: current_user
      )

      expect(result).to be_success
    end

    context 'when event.use_ticket is true (Exhibitor)' do
      context 'with vendor_id provided' do
        let(:vendor) { create(:user, :vendor) }
        let(:params) do
          {
            vendor_id: vendor.id,
            redirect_url: 'https://example.com'
          }
        end

        it 'creates an Exhibitor' do
          result = EventVendorService.create(event: event, params: params, current_user: current_user)

          expect(result).to be_success
          expect(result.data).to be_an(Exhibitor)
          expect(result.data.exhibitor_kit).to be_nil # No exhibitor_kit_attributes passed
        end
      end

      context 'with new vendor creation' do
        let(:params) do
          {
            full_name: 'John Doe',
            email: 'john@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            redirect_url: 'https://example.com'
          }
        end

        it 'creates an Exhibitor with new vendor user' do
          result = EventVendorService.create(event: event, params: params, current_user: current_user)

          expect(result).to be_success
          expect(result.data).to be_an(Exhibitor)
          expect(result.data.vendor.email).to eq('john@example.com')
          expect(result.data.exhibitor_kit).to be_nil
        end
      end
    end

    context 'when event.use_ticket is false (Merchant)' do
      let(:event) { create(:event, use_ticket: false) }

      context 'with vendor_id provided' do
        let(:vendor) { create(:user, :vendor) }
        let(:params) do
          {
            vendor_id: vendor.id,
            redirect_url: 'https://example.com'
          }
        end

        it 'creates a Merchant' do
          result = EventVendorService.create(event: event, params: params, current_user: current_user)

          expect(result).to be_success
          expect(result.data).to be_a(Merchant)
        end
      end

      context 'with new vendor creation' do
        let(:params) do
          {
            full_name: 'Jane Doe',
            email: 'jane@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            redirect_url: 'https://example.com'
          }
        end

        it 'creates a Merchant with new vendor user' do
          result = EventVendorService.create(event: event, params: params, current_user: current_user)

          expect(result).to be_success
          expect(result.data).to be_a(Merchant)
          expect(result.data.vendor.email).to eq('jane@example.com')
        end
      end
    end

    context 'when user is not an organizer' do
      let(:non_organizer) { create(:user, :member) }
      let(:params) do
        {
          full_name: 'John Doe',
          email: 'john@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          redirect_url: 'https://example.com'
        }
      end

      it 'returns error when trying to create new vendor' do
        result = EventVendorService.create(event: event, params: params, current_user: non_organizer)

        expect(result).to be_failure
        expect(result.errors).to include('Only organizers can create new vendor users')
      end
    end

    context 'email generation' do
      let(:event) { create(:event, title: 'Tech Conference 2024', use_ticket: false) }
      let(:params) do
        {
          full_name: 'John Doe',
          email: '',
          password: 'password123',
          password_confirmation: 'password123',
          redirect_url: 'https://example.com'
        }
      end

      it 'generates email when not provided' do
        result = EventVendorService.create(event: event, params: params, current_user: current_user)

        expect(result).to be_success
        expect(result.data.vendor.email).to match(/vendor_tech_conference_2024_john/)
      end
    end
  end

  describe '.create with a voucher' do
    let(:current_user) { create(:user, :organizer) }
    let(:event) { create(:event, use_exhibitor_kit: true) }
    let(:booth_price) { create(:exhibitor_booth_price, event: event, price: 1000) }
    let!(:voucher) do
      create(:exhibitor_voucher, event: event, discount_type: :fixed_amount_off, discount_value: 400)
    end
    let(:kit_attributes) do
      {
        exhibitor_booth_price_id: booth_price.id,
        voucher_code: voucher.code,
        company_name: 'Acme',
        pic_full_name: 'Ada',
        pic_contact_number: '123'
      }
    end

    it 'prices and redeems the voucher when assigning an existing vendor' do
      vendor = create(:user, :vendor)

      result = described_class.create(
        event: event,
        params: { vendor_id: vendor.id, exhibitor_kit_attributes: kit_attributes },
        current_user: current_user
      )

      kit = result.data.exhibitor_kits.last
      expect(result).to be_success
      expect(kit.amount_paid).to eq(600)
      expect(kit.price_snapshot).to eq(600)
      expect(voucher.reload).to be_redeemed
      expect(voucher.redeemed_by_exhibitor_kit).to eq(kit)
    end

    it 'locks the event before checking for an existing assignment' do
      vendor = create(:user, :vendor)
      expect(event).to receive(:lock!).ordered.and_call_original
      expect(described_class).to receive(:existing_vendor_assignment?).ordered.and_call_original

      result = described_class.create(
        event: event,
        params: { vendor_id: vendor.id, exhibitor_kit_attributes: kit_attributes },
        current_user: current_user
      )

      expect(result).to be_success
    end

    it 'translates a unique assignment race into a voucher mismatch' do
      vendor = create(:user, :vendor)
      allow(described_class).to receive(:assign_existing_vendor).and_raise(
        ActiveRecord::RecordNotUnique,
        'duplicate assignment'
      )

      result = described_class.create(
        event: event,
        params: { vendor_id: vendor.id, exhibitor_kit_attributes: kit_attributes },
        current_user: current_user
      )

      expect(result).to be_failure
      expect(result.errors).to contain_exactly(ExhibitorVoucherRedemption::MISMATCH_MESSAGE)
      expect(voucher.reload).to be_active
    end

    it 'prices and redeems the voucher when creating a vendor user' do
      result = described_class.create(
        event: event,
        params: {
          full_name: 'New Vendor',
          email: 'new-voucher-vendor@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          exhibitor_kit_attributes: kit_attributes
        },
        current_user: current_user
      )

      kit = result.data.exhibitor_kits.last
      expect(result).to be_success
      expect(kit.amount_paid).to eq(600)
      expect(kit.price_snapshot).to eq(600)
      expect(voucher.reload).to be_redeemed
      expect(voucher.redeemed_by_exhibitor_kit).to eq(kit)
    end
  end

  describe '.assign_existing_vendor' do
    let(:event) { create(:event, use_ticket: true) }
    let(:vendor) { create(:user, :vendor) }
    let(:params) do
      {
        redirect_url: 'https://example.com'
      }
    end

    it 'assigns existing vendor and creates Exhibitor' do
      result = EventVendorService.assign_existing_vendor(event, vendor.id, params, 'Exhibitor')

      expect(result).to be_success
      expect(result.data).to be_an(Exhibitor)
      expect(result.data.vendor_id).to eq(vendor.id)
    end

    it 'updates the legacy kit without appending a kit when assignment is retried' do
      exhibitor = create(:exhibitor, event: event, vendor: vendor)
      kit = create(:exhibitor_kit, event_vendor: exhibitor, booth_number: 'A1')

      result = EventVendorService.assign_existing_vendor(
        event, vendor.id, params, 'Exhibitor', { booth_number: 'B2' }
      )

      expect(result).to be_success
      expect(exhibitor.reload.exhibitor_kits).to contain_exactly(kit)
      expect(kit.reload.booth_number).to eq('B2')
    end

    it 'does not create a kit when an assignment without one is retried' do
      exhibitor = create(:exhibitor, event: event, vendor: vendor)

      result = EventVendorService.assign_existing_vendor(
        event, vendor.id, params, 'Exhibitor', { booth_number: 'B2' }
      )

      expect(result).to be_success
      expect(exhibitor.reload.exhibitor_kits).to be_empty
    end

    it 'returns error when vendor not found' do
      result = EventVendorService.assign_existing_vendor(event, 99999, params, 'Exhibitor')

      expect(result).to be_failure
      expect(result.errors).to include('Vendor not found')
    end
  end

  describe '.create_vendor_user' do
    let(:event) { create(:event, use_ticket: false) }
    let(:params) do
      {
        full_name: 'John Doe',
        email: 'john@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        redirect_url: 'https://example.com'
      }
    end

    it 'creates new vendor user and Merchant' do
      result = EventVendorService.create_vendor_user(params, event, 'Merchant')

      expect(result).to be_success
      expect(result.data).to be_a(Merchant)
      expect(result.data.vendor.email).to eq('john@example.com')
    end

    it 'handles existing vendor user' do
      existing_vendor = create(:user, :vendor, email: 'john@example.com')

      result = EventVendorService.create_vendor_user(params, event, 'Merchant')

      expect(result).to be_success
      expect(result.data.vendor_id).to eq(existing_vendor.id)
    end
  end
end
