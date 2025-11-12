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

  describe '.validate_exhibitor_params' do
    context 'when exhibitor_owner_id is blank' do
      let(:params) { { exhibitor_owner_id: nil } }

      it 'returns success result (exhibitor_owner_id is optional)' do
        result = EventVendorService.validate_exhibitor_params(params)
        expect(result).to be_success
      end
    end

    context 'when exhibitor_owner_id does not exist' do
      let(:params) { { exhibitor_owner_id: 99999 } }

      it 'returns failure result with error' do
        result = EventVendorService.validate_exhibitor_params(params)
        expect(result).to be_failure
        expect(result.errors).to include('ExhibitorOwner not found')
      end
    end

    context 'when exhibitor_owner_id exists' do
      let(:exhibitor_owner) { create(:exhibitor_owner) }
      let(:params) { { exhibitor_owner_id: exhibitor_owner.id } }

      it 'returns success result' do
        result = EventVendorService.validate_exhibitor_params(params)
        expect(result).to be_success
      end
    end
  end

  describe '.create' do
    let(:current_user) { create(:manager_user) }
    let(:event) { create(:event, use_ticket: true) }
    let(:exhibitor_owner) { create(:exhibitor_owner) }

    context 'when event.use_ticket is true (Exhibitor)' do
      context 'with vendor_id provided' do
        let(:vendor) { create(:vendor_user) }
        let(:params) do
          {
            vendor_id: vendor.id,
            redirect_url: 'https://example.com',
            exhibitor_owner_id: exhibitor_owner.id
          }
        end

        it 'creates an Exhibitor' do
          result = EventVendorService.create(event: event, params: params, current_user: current_user)

          expect(result).to be_success
          expect(result.data).to be_an(Exhibitor)
          expect(result.data.exhibitor_owner_id).to eq(exhibitor_owner.id)
        end

        it 'allows creating Exhibitor without exhibitor_owner_id (independent exhibitor)' do
          params_without_owner = params.except(:exhibitor_owner_id)
          result = EventVendorService.create(event: event, params: params_without_owner, current_user: current_user)

          expect(result).to be_success
          expect(result.data).to be_an(Exhibitor)
          expect(result.data.exhibitor_owner_id).to be_nil
          expect(result.data.independent?).to be_truthy
        end
      end

      context 'with new vendor creation' do
        let(:params) do
          {
            full_name: 'John Doe',
            email: 'john@example.com',
            password: 'password123',
            password_confirmation: 'password123',
            redirect_url: 'https://example.com',
            exhibitor_owner_id: exhibitor_owner.id
          }
        end

        it 'creates an Exhibitor with new vendor user' do
          result = EventVendorService.create(event: event, params: params, current_user: current_user)

          expect(result).to be_success
          expect(result.data).to be_an(Exhibitor)
          expect(result.data.vendor.email).to eq('john@example.com')
          expect(result.data.exhibitor_owner_id).to eq(exhibitor_owner.id)
        end
      end
    end

    context 'when event.use_ticket is false (Merchant)' do
      let(:event) { create(:event, use_ticket: false) }

      context 'with vendor_id provided' do
        let(:vendor) { create(:vendor_user) }
        let(:params) do
          {
            vendor_id: vendor.id,
            redirect_url: 'https://example.com',
            exhibitor_owner_id: exhibitor_owner.id # Should be ignored
          }
        end

        it 'creates a Merchant' do
          result = EventVendorService.create(event: event, params: params, current_user: current_user)

          expect(result).to be_success
          expect(result.data).to be_a(Merchant)
          expect(result.data.exhibitor_owner_id).to be_nil
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

    context 'when user is not a manager' do
      let(:non_manager) { create(:member_user) }
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
        result = EventVendorService.create(event: event, params: params, current_user: non_manager)

        expect(result).to be_failure
        expect(result.errors).to include('Only managers can create new vendor users')
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
    let(:vendor) { create(:vendor_user) }
    let(:exhibitor_owner) { create(:exhibitor_owner) }
    let(:params) do
      {
        redirect_url: 'https://example.com',
        exhibitor_owner_id: exhibitor_owner.id
      }
    end

    it 'assigns existing vendor and creates Exhibitor' do
      result = EventVendorService.assign_existing_vendor(event, vendor.id, params, 'Exhibitor')

      expect(result).to be_success
      expect(result.data).to be_an(Exhibitor)
      expect(result.data.vendor_id).to eq(vendor.id)
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
      existing_vendor = create(:vendor_user, email: 'john@example.com')

      result = EventVendorService.create_vendor_user(params, event, 'Merchant')

      expect(result).to be_success
      expect(result.data.vendor_id).to eq(existing_vendor.id)
    end
  end
end
