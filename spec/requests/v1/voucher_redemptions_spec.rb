require 'swagger_helper'

RSpec.describe 'V1::VoucherRedemptions', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # ============================================================
  # Shared Constants & Schemas
  # ============================================================
  VOUCHER_REDEMPTION_SUCCESS_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean, example: true },
      message: { type: :string, example: 'Voucher redeemed successfully' },
      data: {
        type: :object,
        properties: {
          net_amount: { type: :string, example: '75.0', description: 'Final amount after discount' },
          discount_applied: { type: :string, example: '25.0', description: 'Discount amount applied' },
          voucher_type: { type: :string, example: 'fixed_amount', enum: ['fixed_amount', 'percentage', 'free_item'] }
        },
        required: %w[net_amount discount_applied voucher_type]
      }
    },
    required: %w[success message data]
  }.freeze

  VOUCHER_REDEMPTION_ERROR_SCHEMA = {
    type: :object,
    properties: {
      success: { type: :boolean, example: false },
      message: { type: :string, example: 'Voucher has expired or is not yet active.' }
    },
    required: %w[success message]
  }.freeze
  let!(:vendor_user) { create(:user, :vendor) }
  let!(:event) { create(:event) }
  let!(:user) { create(:user) }
  let!(:non_vendor_user) { create(:user) } # Regular user (not vendor)

  # Mock User Role Methods for Policies
  before(:each) do
    allow_any_instance_of(User).to receive(:is_org_owner?).and_return(false)
    allow_any_instance_of(User).to receive(:is_organizer?).and_return(false)
    allow(vendor_user).to receive(:is_vendor?).and_return(true)
    allow(non_vendor_user).to receive(:is_vendor?).and_return(false)
  end

  # JWT/Header Setup
  def token_for(user)
    "Bearer #{JwtService.generate_tokens(user)[:access_token]}"
  end

  let(:auth_headers) { { 'Authorization' => token_for(vendor_user), 'Content-Type' => 'application/json' } }
  let(:non_vendor_headers) { { 'Authorization' => token_for(non_vendor_user), 'Content-Type' => 'application/json' } }

  # Helper methods
  def json_response
    JSON.parse(response.body)
  end

  def response_success
    json_response['success']
  end

  def response_message
    json_response['message']
  end

  def response_data
    json_response['data']
  end

  # Set time zone for time-based validations
  around do |example|
    Time.use_zone('Asia/Kuala_Lumpur') { example.run }
  end

  # ============================================================
  # POST /v1/voucher_redemptions
  # ============================================================
  path '/v1/voucher_redemptions' do
    post 'Redeems a voucher' do
      tags 'Voucher Redemptions'
      security [{ BearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :voucher_redemption, in: :body, required: true, schema: {
        type: :object,
        properties: {
          voucher_uuid: {
            type: :string,
            format: :uuid,
            example: '550e8400-e29b-41d4-a716-446655440000',
            description: 'UUID of the voucher to redeem'
          },
          net_amount: {
            type: :number,
            format: :decimal,
            example: 75.00,
            description: 'Purchase amount after discount (required)'
          },
          user_id: {
            type: :integer,
            example: 123,
            description: 'Optional: User ID to redeem for. Cannot be used with visitor_id.'
          },
          visitor_id: {
            type: :string,
            format: :uuid,
            example: '550e8400-e29b-41d4-a716-446655440000',
            description: 'Optional: Visitor public_id to redeem for. Cannot be used with user_id.'
          }
        },
        required: %w[voucher_uuid net_amount]
      }

      let(:Authorization) { auth_headers['Authorization'] }
      let(:valid_date) { 1.day.from_now.to_date }
      let(:valid_start_time) { Time.zone.parse('00:00:00') }
      let(:valid_end_time) { Time.zone.parse('23:59:59') }

      def create_valid_voucher(overrides = {})
        create(:voucher, {
          vendor: vendor_user,
          event: event,
          end_date: valid_date,
          start_time: valid_start_time,
          end_time: valid_end_time
        }.merge(overrides))
      end

      response '201', 'Voucher redeemed successfully' do
        let(:voucher) { create_valid_voucher(voucher_type: :fixed_amount, voucher_value: 25.00) }
        let(:voucher_redemption) do
          {
            voucher_uuid: voucher.voucher_uuid,
            net_amount: 75.00
          }
        end

        schema VOUCHER_REDEMPTION_SUCCESS_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(true)
          expect(data['message']).to eq('Voucher redeemed successfully')
          expect(data['data']['net_amount']).to eq('75.0')
          expect(data['data']['discount_applied']).to eq('25.0')
          expect(data['data']['voucher_type']).to eq('fixed_amount')

          # Verify redemption log was created
          expect(VoucherRedemptionLog.count).to eq(1)
          log = VoucherRedemptionLog.last
          expect(log.voucher_id).to eq(voucher.id)
          expect(log.redeemer_id).to eq(vendor_user.id)
          expect(log.redeemer_type).to eq('User') # Rails polymorphic convention
          expect(log.redeemer).to eq(vendor_user) # Verify polymorphic association
        end
      end

      response '201', 'Voucher redeemed successfully (percentage discount)' do
        let(:voucher) { create_valid_voucher(voucher_type: :percentage, voucher_value: 10) }
        let(:voucher_redemption) do
          {
            voucher_uuid: voucher.voucher_uuid,
            net_amount: 270.00
          }
        end

        schema VOUCHER_REDEMPTION_SUCCESS_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['net_amount']).to eq('270.0')
          expect(data['data']['discount_applied']).to eq('30.0')
        end
      end

      response '201', 'Voucher redeemed successfully (vendor redeeming for another user)' do
        let(:voucher) { create_valid_voucher }
        let(:other_user) { create(:user) }
        let(:voucher_redemption) do
          {
            voucher_uuid: voucher.voucher_uuid,
            user_id: other_user.id,
            net_amount: 75.00
          }
        end

        schema VOUCHER_REDEMPTION_SUCCESS_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(true)

          # Verify the redemption log is for the specified user
          log = VoucherRedemptionLog.last
          expect(log.redeemer_id).to eq(other_user.id)
          expect(log.redeemer_type).to eq('User') # Rails polymorphic convention
          expect(log.redeemer).to eq(other_user) # Verify polymorphic association
          expect(log.redeemer_staff_id).to eq(vendor_user.id)
        end
      end

      response '422', 'Voucher validation failed (expired)' do
        let(:expired_voucher) do
          create(:voucher,
            vendor: vendor_user,
            event: event,
            end_date: 1.day.ago.to_date,
            start_time: valid_start_time,
            end_time: valid_end_time
          )
        end
        let(:voucher_redemption) do
          {
            voucher_uuid: expired_voucher.voucher_uuid,
            net_amount: 75.00
          }
        end

        schema VOUCHER_REDEMPTION_ERROR_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(data['message']).to include('expired')
          expect(VoucherRedemptionLog.count).to eq(0)
        end
      end

      response '422', 'Voucher validation failed (global limit reached)' do
        let(:limited_voucher) do
          create_valid_voucher(total_redemption_available: 1)
        end
        let(:voucher_redemption) do
          {
            voucher_uuid: limited_voucher.voucher_uuid,
            user_id: user.id,
            net_amount: 75.00
          }
        end

        before do
          # First redemption to consume the limit
          VoucherRedemptionService.call(
            voucher: limited_voucher,
            redeemer: create(:user),
            vendor_id: vendor_user.id,
            net_amount: 75.00
          )
        end

        schema VOUCHER_REDEMPTION_ERROR_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(data['message']).to include('out of stock')
        end
      end

      response '422', 'Voucher validation failed (user limit reached)' do
        let(:user_limited_voucher) do
          create_valid_voucher(max_redemptions_per_user: 1)
        end
        let(:voucher_redemption) do
          {
            voucher_uuid: user_limited_voucher.voucher_uuid,
            user_id: user.id,
            net_amount: 75.00
          }
        end

        before do
          # First redemption to consume user's limit
          VoucherRedemptionService.call(
            voucher: user_limited_voucher,
            redeemer: user,
            vendor_id: vendor_user.id,
            net_amount: 75.00
          )
        end

        schema VOUCHER_REDEMPTION_ERROR_SCHEMA

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(data['message']).to include('personal limit')
        end
      end

      response '404', 'Voucher not found' do
        let(:voucher_redemption) do
          {
            voucher_uuid: '00000000-0000-0000-0000-000000000000',
            net_amount: 75.00
          }
        end

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string, example: 'Voucher not found' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(data['message']).to eq('Voucher not found')
        end
      end

      response '404', 'Redeemer not found' do
        let(:voucher) { create_valid_voucher }
        let(:voucher_redemption) do
          {
            voucher_uuid: voucher.voucher_uuid,
            user_id: 99999,
            net_amount: 75.00
          }
        end

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string, example: 'Redeemer not found' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(data['message']).to eq('Redeemer not found')
        end
      end

      response '403', 'Forbidden - Only vendors can redeem vouchers' do
        let(:voucher) { create_valid_voucher }
        let(:Authorization) { non_vendor_headers['Authorization'] }
        let(:voucher_redemption) do
          {
            voucher_uuid: voucher.voucher_uuid,
            net_amount: 75.00
          }
        end

        schema type: :object,
               properties: {
                 success: { type: :boolean, example: false },
                 message: { type: :string, example: 'Only vendors can redeem vouchers' }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['success']).to be(false)
          expect(data['message']).to eq('Only vendors can redeem vouchers')
        end
      end

      response '400', 'Bad Request - Missing required parameters' do
        let(:voucher) { create_valid_voucher }
        let(:voucher_redemption) do
          {
            voucher_uuid: voucher.voucher_uuid
            # net_amount is missing
          }
        end
      end
    end
  end
end
