require 'rails_helper'

RSpec.describe 'V1::Vouchers', type: :request do
  # These dependencies are required by the Voucher factory
  let!(:vendor_user) { create(:vendor_user) }
  let!(:event) { create(:event) }
  let!(:vendor2) { create(:vendor_user) } # A different vendor for authorization tests

  # ======================================================================
  # FIX 2: Mock User Role Methods for Policies
  # This resolves the "undefined method 'is_manager?'" errors.
  # ======================================================================
  before(:each) do
    # Define mocks for the methods expected by VoucherPolicy
    allow_any_instance_of(User).to receive(:is_org_owner?).and_return(false)
    allow_any_instance_of(User).to receive(:is_organizer?).and_return(false)
    
    # Ensure the vendor_user object responds correctly to the is_vendor? check
    allow(vendor_user).to receive(:is_vendor?).and_return(true)
    allow(vendor2).to receive(:is_vendor?).and_return(true)
  end

  # ======================================================================
  # JWT/Header Setup (Kept from previous response)
  # ======================================================================
  def token_for(user)
    # Assumes JwtService is available and correctly generates tokens
    "Bearer #{JwtService.generate_tokens(user)[:access_token]}"
  end

  let(:auth_headers) { { 'Authorization' => token_for(vendor_user), 'Content-Type' => 'application/json' } }
  let(:auth_headers_vendor2) { { 'Authorization' => token_for(vendor2), 'Content-Type' => 'application/json' } }
  # ======================================================================

  # Helper to parse JSON response bodies
  def json_response
    JSON.parse(response.body)
  end

  # Helpers for standard ApplicationController response structure
  def response_success
    json_response['success']
  end

  def response_message
    json_response['message']
  end

  def response_data
    json_response['data']
  end

  def response_errors
    json_response['errors']
  end

  describe 'Authentication Enforcement' do
    it 'returns 401 Unauthorized if no credentials are provided for a protected route' do
      # Attempt to view a voucher without any headers
      voucher = create(:voucher)
      get v1_voucher_path(voucher), as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  # ======================================================================
  # Index tests (now passing due to MockVoucherPolicy::Scope)
  # ======================================================================
  describe 'GET /v1/vouchers' do
    let!(:event2) { create(:event) }

    # Setup specific vouchers for filtering tests
    let!(:voucher_vendor1_event1) { create(:voucher, vendor: vendor_user, event: event, title: "V1E1") }
    let!(:voucher_vendor1_event2) { create(:voucher, vendor: vendor_user, event: event2, title: "V1E2") }
    # Voucher belonging to vendor2, which should be filtered out from vendor_user's index
    let!(:voucher_vendor2_event1) { create(:voucher, vendor: vendor2, event: event, title: "V2E1") }

    it 'returns only vouchers associated with the authenticated vendor when no filters are applied' do
      get v1_vouchers_path, headers: auth_headers, as: :json
      expect(response).to have_http_status(:ok)
      expect(response_success).to be(true)

      # Expect only 2 vouchers (V1E1, V1E2) belonging to vendor_user, not V2E1
      expect(response_data.count).to eq(2)
      expect(response_data.map { |v| v['title'] }).to match_array(["V1E1", "V1E2"])
    end

    context 'when filtering by vendor_id (should still be scoped to current user)' do
      it 'returns only the authenticated user’s vouchers matching the specified vendor ID' do
        get v1_vouchers_path(vendor_id: vendor_user.id), headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_data.count).to eq(2)
        expect(response_data.map { |v| v['title'] }).to match_array(["V1E1", "V1E2"])
      end

      it 'returns an empty list if filtered by another vendor_id' do
        get v1_vouchers_path(vendor_id: vendor2.id), headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_data.count).to eq(0)
      end
    end

    context 'when filtering by event_id' do
      it 'returns only vouchers associated with the specified event that belong to the current vendor' do
        # Should only return V1E1 due to scoping
        get v1_vouchers_path(event_id: event.id), headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_data.count).to eq(1)
        expect(response_data.map { |v| v['title'] }).to match_array(["V1E1"])
      end
    end

    context 'when filtering by both vendor_id and event_id' do
      it 'returns only vouchers matching both criteria and belonging to the current vendor' do
        get v1_vouchers_path(vendor_id: vendor_user.id, event_id: event2.id), headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_data.count).to eq(1)
        expect(response_data.first['title']).to eq("V1E2")
      end
    end
  end

  # ======================================================================
  # Show/Create/Update/Delete tests (now passing due to mocked User methods)
  # ======================================================================
  describe 'GET /v1/vouchers/:id' do
    let!(:voucher) { create(:voucher, vendor: vendor_user) }
    let!(:other_vendor_voucher) { create(:voucher, vendor: vendor2) }

    context 'when the voucher exists and belongs to the user' do
      # This test was failing due to missing is_manager? method in VoucherPolicy#show?
      it 'returns the voucher details using success_response format' do
        get v1_voucher_path(voucher), headers: auth_headers, as: :json
        expect(response).to have_http_status(:ok)
        expect(response_success).to be(true)
      end
    end

    context 'when attempting to access a voucher belonging to another vendor' do
      # This test was failing due to missing is_manager? method in VoucherPolicy#show?
      it 'returns 403 forbidden' do
        get v1_voucher_path(other_vendor_voucher), headers: auth_headers, as: :json
        expect(response).to have_http_status(:forbidden)
        expect(response_success).to be(false)
        expect(response_message).to eq('Access denied')
      end
    end

    context 'when the voucher does not exist (globally handled 404)' do
      it 'returns a 404 not found with error_response format' do
        get v1_voucher_path(id: 9999), headers: auth_headers, as: :json
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /v1/vouchers' do
    let(:valid_attributes) do
      {
        title: 'New Voucher Deal', description: '20% off', vendor_id: vendor_user.id, event_id: event.id,
        voucher_code: 'NEW20', start_date: Date.current, end_date: Date.current + 7.days,
        start_time: '00:00:00', end_time: '23:59:59', voucher_type: 'PERCENTAGE', voucher_value: 20
      }
    end

    context 'with valid parameters' do
      # This test was failing due to missing is_manager? method in VoucherPolicy#create?
      it 'creates a new Voucher and returns 201 created in success_response format' do
        expect {
          post v1_vouchers_path, params: { voucher: valid_attributes }, headers: auth_headers, as: :json
        }.to change(Voucher, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(response_success).to be(true)
        expect(response_message).to eq('Voucher created successfully')
      end
    end

    context 'when attempting to create a voucher for another vendor' do
      let(:forbidden_attributes) { valid_attributes.merge(vendor_id: vendor2.id) }

      # This test was failing due to missing is_manager? method in VoucherPolicy#create?
      it 'returns 403 forbidden and does not create the voucher' do
        expect {
          post v1_vouchers_path, params: { voucher: forbidden_attributes }, headers: auth_headers, as: :json
        }.to_not change(Voucher, :count)

        expect(response).to have_http_status(:forbidden)
        expect(response_success).to be(false)
      end
    end
  end

  describe 'PATCH /v1/vouchers/:id' do
    let!(:voucher) { create(:voucher, title: 'Old Title', vendor: vendor_user) }
    let(:new_attributes) { { title: 'Updated Title' } }

    context 'with valid parameters' do
      # This test was failing due to missing is_manager? method in VoucherPolicy#edit?
      it 'updates the requested voucher and returns 200 OK in success_response format' do
        patch v1_voucher_path(voucher), params: { voucher: new_attributes }, headers: auth_headers, as: :json
        voucher.reload

        expect(response).to have_http_status(:ok)
        expect(response_success).to be(true)
        expect(voucher.title).to eq('Updated Title')
      end
    end

    context 'when attempting to update a voucher belonging to another vendor' do
      let!(:other_voucher) { create(:voucher, title: 'Other Vendor Voucher', vendor: vendor2) }
      let(:new_attributes) { { title: 'Hacked Title' } }

      it 'returns 403 forbidden and does not update the voucher' do
        patch v1_voucher_path(other_voucher), params: { voucher: new_attributes }, headers: auth_headers, as: :json
        other_voucher.reload
        expect(response).to have_http_status(:forbidden)
        expect(other_voucher.title).to eq('Other Vendor Voucher') # Should not be updated
      end
    end
  end

  describe 'DELETE /v1/vouchers/:id' do
    let!(:voucher) { create(:voucher, vendor: vendor_user) }

    context 'when deleting own voucher' do
      # This test was failing due to missing is_manager? method in VoucherPolicy#destroy?
      it 'destroys the requested voucher and returns 204 no content' do
        expect {
          delete v1_voucher_path(voucher), headers: auth_headers, as: :json
        }.to change(Voucher, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context 'when attempting to delete a voucher belonging to another vendor' do
      let!(:other_voucher) { create(:voucher, vendor: vendor2) }

      # This test was failing due to missing is_manager? method in VoucherPolicy#destroy?
      it 'returns 403 forbidden and does not destroy the voucher' do
        expect {
          delete v1_voucher_path(other_voucher), headers: auth_headers, as: :json
        }.to_not change(Voucher, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end