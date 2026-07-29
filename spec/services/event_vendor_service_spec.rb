# spec/services/event_vendor_service_spec.rb

require 'rails_helper'

RSpec.describe EventVendorService, type: :service do
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
