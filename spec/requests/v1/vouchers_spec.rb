require 'swagger_helper'

RSpec.describe 'V1::Vouchers', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  VOUCHER_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer },
      title: { type: :string, example: '20% Off Deal' },
      description: { type: :string, nullable: true, example: 'Get 20% off on all items' },
      voucher_uuid: { type: :string, format: :uuid },
      voucher_code: { type: :string, example: 'SAVE20' },
      status: { type: :string, example: 'active' },
      vendor_id: { type: :integer },
      event_id: { type: :integer },
      start_date: { type: :string, format: :date, example: '2024-01-01' },
      end_date: { type: :string, format: :date, example: '2024-12-31' },
      start_time: { type: :string, format: :time, example: '00:00:00' },
      end_time: { type: :string, format: :time, example: '23:59:59' },
      total_redemption_available: { type: :integer, nullable: true, example: 100 },
      is_unlimited: { type: :boolean, example: false },
      redeemed_count: { type: :integer, example: 0 },
      max_redemptions_per_user: { type: :integer, nullable: true, example: 5 },
      voucher_type: { type: :string, enum: ['fixed_amount', 'percentage', 'free_item'], example: 'percentage' },
      voucher_value: { type: :string, example: '20.00' },
      image_path: { type: :string, nullable: true, example: 'https://example.com/images/voucher.jpg' },
      created_at: { type: :string, format: :date_time },
      updated_at: { type: :string, format: :date_time }
    },
    required: %w[id title voucher_uuid vendor_id event_id]
  }.freeze

  VOUCHER_LIST_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean, example: true },
      message: { type: :string, example: 'Success' },
      data: {
        type: :array,
        items: VOUCHER_SCHEMA,
        example: [
          {
            id: 1,
            title: '20% Off Deal',
            description: 'Get 20% off on all items',
            voucher_uuid: '550e8400-e29b-41d4-a716-446655440000',
            voucher_code: 'SAVE20',
            status: 'active',
            vendor_id: 1,
            event_id: 1,
            start_date: '2024-01-01',
            end_date: '2024-12-31',
            start_time: '00:00:00',
            end_time: '23:59:59',
            total_redemption_available: 100,
            redeemed_count: 0,
            max_redemptions_per_user: 5,
            voucher_type: 'percentage',
            voucher_value: '20.00',
            created_at: '2024-01-01T00:00:00.000Z',
            updated_at: '2024-01-01T00:00:00.000Z'
          },
          {
            id: 2,
            title: 'Free Item Voucher',
            description: 'Get a free item with purchase',
            voucher_uuid: '660e8400-e29b-41d4-a716-446655440001',
            voucher_code: 'FREEITEM',
            status: 'active',
            vendor_id: 1,
            event_id: 1,
            start_date: '2024-01-01',
            end_date: '2024-12-31',
            start_time: '00:00:00',
            end_time: '23:59:59',
            total_redemption_available: 50,
            redeemed_count: 5,
            max_redemptions_per_user: 1,
            voucher_type: 'free_item',
            voucher_value: '0.00',
            created_at: '2024-01-01T00:00:00.000Z',
            updated_at: '2024-01-01T00:00:00.000Z'
          }
        ]
      }
    },
    required: %w[success message]
  }.freeze

  VOUCHER_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean, example: true },
      message: { type: :string, example: 'Success' },
      data: {
        type: :object
      }
    },
    required: %w[success message]
  }.freeze

  VOUCHER_ERROR_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean, example: false },
      message: { type: :string, example: 'Validation failed' },
      errors: {
        type: :array,
        items: { type: :string },
        example: ['Title can\'t be blank']
      }
    },
    required: %w[success message]
  }.freeze
  # These dependencies are required by the Voucher factory
  let!(:vendor_user) { create(:user, :vendor) }
  let!(:event) { create(:event) }
  let!(:vendor2) { create(:user, :vendor) } # A different vendor for authorization tests

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

  # ============================================================
  # GET /v1/vouchers (Index)
  # ============================================================
  path '/v1/vouchers' do
    get 'Lists vouchers' do
      tags 'Vouchers'
      security [{ BearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :vendor_id, in: :query, type: :integer, required: false, description: 'Filter by vendor ID'
      parameter name: :event_id, in: :query, type: :integer, required: false, description: 'Filter by event ID'

      let(:Authorization) { auth_headers['Authorization'] }
      let!(:event2) { create(:event) }
      let!(:voucher_vendor1_event1) { create(:voucher, vendor: vendor_user, event: event, title: "V1E1") }
      let!(:voucher_vendor1_event2) { create(:voucher, vendor: vendor_user, event: event2, title: "V1E2") }
      let!(:voucher_vendor2_event1) { create(:voucher, vendor: vendor2, event: event, title: "V2E1") }

      response '200', 'Vouchers retrieved successfully' do
        schema VOUCHER_LIST_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(true)
          expect(data['data']).to be_an(Array)
          # Should only return vouchers for vendor_user
          titles = data['data'].map { |v| v['title'] }
          expect(titles).to match_array(["V1E1", "V1E2"])
        end
      end

      response '200', 'Vouchers filtered by event_id' do
        let(:event_id) { event.id }

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: true },
                 message: { type: :string, example: 'Success' },
                 data: {
                   type: :array,
                   items: VOUCHER_SCHEMA,
                   example: [
                     {
                       id: 1,
                       title: 'V1E1',
                       voucher_uuid: '550e8400-e29b-41d4-a716-446655440000',
                       vendor_id: 1,
                       event_id: 1,
                       voucher_code: 'SAVE20',
                       status: 'active',
                       voucher_type: 'percentage',
                       voucher_value: '20.00'
                     }
                   ]
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(true)
          expect(data['data'].count).to eq(1)
          expect(data['data'].first['title']).to eq("V1E1")
        end
      end

      response '401', 'Unauthorized' do
        let(:Authorization) { nil }

        schema type: :object,
               properties: {
                 error: { type: :string, example: 'Unauthorized' }
               }

        run_test!
      end
    end
  end

  # ============================================================
  # GET /v1/vouchers/:id (Show)
  # ============================================================
  path '/v1/vouchers/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true, description: 'Voucher ID'

    get 'Retrieves a voucher' do
      tags 'Vouchers'
      security [{ BearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      let(:Authorization) { auth_headers['Authorization'] }
      let!(:voucher) { create(:voucher, vendor: vendor_user) }

      response '200', 'Voucher retrieved successfully' do
        let(:id) { voucher.id }

        schema VOUCHER_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(true)
          expect(data['data']['id']).to eq(voucher.id)
        end
      end

      response '403', 'Forbidden - Access denied' do
        let(:id) { create(:voucher, vendor: vendor2).id }

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string, example: 'You are not authorized to show? this voucher.' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(data['message']).to include('not authorized')
        end
      end

      response '404', 'Voucher not found' do
        let(:id) { 99999 }

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string, example: 'Resource not found' }
               }

        run_test!
      end
    end
  end

  # ============================================================
  # POST /v1/vouchers (Create)
  # ============================================================
  path '/v1/vouchers' do
    post 'Creates a new voucher' do
      tags 'Vouchers'
      security [{ BearerAuth: [] }]
      consumes 'multipart/form-data'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :title, in: :formData, type: :string, required: true, description: 'Voucher title'
      parameter name: :description, in: :formData, type: :string, required: false, description: 'Voucher description'
      parameter name: :vendor_id, in: :formData, type: :integer, required: true, description: 'Vendor user ID'
      parameter name: :event_id, in: :formData, type: :integer, required: true, description: 'Event ID'
      parameter name: :voucher_code, in: :formData, type: :string, required: true, description: 'Unique voucher code'
      parameter name: :status, in: :formData, type: :string, required: false, description: 'Voucher status'
      parameter name: :start_date, in: :formData, type: :string, required: true, description: 'Start date'
      parameter name: :end_date, in: :formData, type: :string, required: true, description: 'End date'
      parameter name: :start_time, in: :formData, type: :string, required: true, description: 'Start time'
      parameter name: :end_time, in: :formData, type: :string, required: true, description: 'End time'
      parameter name: :total_redemption_available, in: :formData, type: :integer, required: false
      parameter name: :is_unlimited, in: :formData, type: :boolean, required: false, description: 'If true, voucher has no redemption quota limit'
      parameter name: :max_redemptions_per_user, in: :formData, type: :integer, required: false
      parameter name: :voucher_type, in: :formData, type: :string, required: true, description: 'Voucher type'
      parameter name: :voucher_value, in: :formData, type: :number, required: true, description: 'Voucher value'
      parameter name: :image, in: :formData, type: :file, required: false, description: 'Optional voucher image'

      let(:Authorization) { auth_headers['Authorization'] }

      response '201', 'Voucher created successfully' do
        let(:title) { 'New Voucher Deal' }
        let(:description) { '20% off' }
        let(:vendor_id) { vendor_user.id }
        let(:event_id) { event.id }
        let(:voucher_code) { 'NEW20' }
        let(:start_date) { Date.current }
        let(:end_date) { Date.current + 7.days }
        let(:start_time) { '00:00:00' }
        let(:end_time) { '23:59:59' }
        let(:voucher_type) { 'percentage' }
        let(:voucher_value) { 20 }

        schema VOUCHER_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(true)
          expect(data['message']).to eq('Voucher created successfully')
          expect(data['data']['title']).to eq('New Voucher Deal')
          expect(Voucher.count).to eq(1)
        end
      end

      response '201', 'Unlimited voucher created successfully' do
        let(:title) { 'Unlimited Voucher' }
        let(:description) { 'No redemption limit' }
        let(:vendor_id) { vendor_user.id }
        let(:event_id) { event.id }
        let(:voucher_code) { 'UNLIMITED2024' }
        let(:start_date) { Date.current }
        let(:end_date) { Date.current + 7.days }
        let(:start_time) { '00:00:00' }
        let(:end_time) { '23:59:59' }
        let(:voucher_type) { 'fixed_amount' }
        let(:voucher_value) { 10 }
        let(:is_unlimited) { true }

        schema VOUCHER_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(true)
          expect(data['message']).to eq('Voucher created successfully')
          expect(data['data']['title']).to eq('Unlimited Voucher')
          expect(data['data']['is_unlimited']).to be(true)
          expect(Voucher.count).to eq(1)
          expect(Voucher.last.is_unlimited).to be(true)
        end
      end

      response '403', 'Forbidden - Cannot create voucher for another vendor' do
        let(:title) { 'New Voucher Deal' }
        let(:vendor_id) { vendor2.id }
        let(:event_id) { event.id }
        let(:voucher_code) { 'NEW20' }
        let(:start_date) { Date.current }
        let(:end_date) { Date.current + 7.days }
        let(:start_time) { '00:00:00' }
        let(:end_time) { '23:59:59' }
        let(:voucher_type) { 'percentage' }
        let(:voucher_value) { 20 }

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(Voucher.count).to eq(0)
        end
      end

      response '422', 'Validation error' do
        let(:title) { 'Test' }
        let(:description) { nil }
        let(:vendor_id) { vendor_user.id }
        # event_id is missing which should cause validation error
        let(:event_id) { nil }
        let(:voucher_code) { nil }
        let(:status) { nil }
        let(:start_date) { nil }
        let(:end_date) { nil }
        let(:start_time) { nil }
        let(:end_time) { nil }
        let(:total_redemption_available) { nil }
        let(:max_redemptions_per_user) { nil }
        let(:voucher_type) { nil }
        let(:voucher_value) { nil }
        let(:image) { nil }

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string },
                 errors: {
                   type: :array,
                   items: { type: :string }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(data['errors']).to be_present
        end
      end
    end
  end

  # ============================================================
  # PATCH /v1/vouchers/:id (Update)
  # ============================================================
  path '/v1/vouchers/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true, description: 'Voucher ID'

    patch 'Updates a voucher' do
      tags 'Vouchers'
      security [{ BearerAuth: [] }]
      consumes 'multipart/form-data'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :title, in: :formData, type: :string, required: false
      parameter name: :description, in: :formData, type: :string, required: false
      parameter name: :voucher_code, in: :formData, type: :string, required: false
      parameter name: :status, in: :formData, type: :string, required: false
      parameter name: :start_date, in: :formData, type: :string, required: false
      parameter name: :end_date, in: :formData, type: :string, required: false
      parameter name: :start_time, in: :formData, type: :string, required: false
      parameter name: :end_time, in: :formData, type: :string, required: false
      parameter name: :total_redemption_available, in: :formData, type: :integer, required: false
      parameter name: :is_unlimited, in: :formData, type: :boolean, required: false, description: 'If true, voucher has no redemption quota limit'
      parameter name: :max_redemptions_per_user, in: :formData, type: :integer, required: false
      parameter name: :voucher_type, in: :formData, type: :string, required: false
      parameter name: :voucher_value, in: :formData, type: :number, required: false
      parameter name: :image, in: :formData, type: :file, required: false, description: 'Optional voucher image'

      let(:Authorization) { auth_headers['Authorization'] }
      let!(:existing_voucher) { create(:voucher, title: 'Old Title', vendor: vendor_user) }

      response '200', 'Voucher updated successfully' do
        let(:id) { existing_voucher.id }
        let(:title) { 'Updated Title' }

        schema VOUCHER_RESPONSE_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(true)
          updated_voucher = Voucher.find(id)
          expect(updated_voucher.title).to eq('Updated Title')
        end
      end

      response '403', 'Forbidden - Cannot update another vendor\'s voucher' do
        let(:id) { create(:voucher, title: 'Other Vendor Voucher', vendor: vendor2).id }
        let(:title) { 'Hacked Title' }

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          other_voucher = Voucher.find(id)
          expect(other_voucher.title).to eq('Other Vendor Voucher')
        end
      end

    end
  end

  # ============================================================
  # DELETE /v1/vouchers/:id (Destroy)
  # ============================================================
  path '/v1/vouchers/{id}' do
    parameter name: :id, in: :path, type: :integer, required: true, description: 'Voucher ID'

    delete 'Deletes a voucher' do
      tags 'Vouchers'
      security [{ BearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      let(:Authorization) { auth_headers['Authorization'] }
      let!(:voucher) { create(:voucher, vendor: vendor_user) }

      response '204', 'Voucher deleted successfully' do
        let(:id) { voucher.id }

        run_test! do |response|
          expect(response.status).to eq(204)
          expect(Voucher.find_by(id: id)).to be_nil
        end
      end

      response '403', 'Forbidden - Cannot delete another vendor\'s voucher' do
        let(:id) { create(:voucher, vendor: vendor2).id }

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(Voucher.find_by(id: id)).to be_present
        end
      end

      response '404', 'Voucher not found' do
        let(:id) { 99999 }

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string, example: 'Resource not found' }
               }

        run_test!
      end
    end
  end
end
