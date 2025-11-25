require 'rails_helper'

# RSpec idiom for chaining negative expectations: define a negated matcher for :change
RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.describe VoucherRedemptionService, type: :service do
  let(:vendor_user) { create(:vendor_user) }
  let(:event) { create(:event) }
  let(:user) { create(:user) }
  let(:gross_amount) { 100.00.to_d }

  # Helper method to simplify the service call
  def call_service(voucher, redeemer_to_use = user, amount = gross_amount)
    described_class.call(
      voucher: voucher,
      redeemer: redeemer_to_use,
      vendor_id: vendor_user.id,
      net_amount: amount
    )
  end

  # Set a consistent time zone for time-based tests
  around do |example|
    # This zone is used in Time.current and Time.zone.local calls inside the service
    Time.use_zone('Asia/Kuala_Lumpur') { example.run }
  end

  # --- SUCCESSFUL REDEMPTION SCENARIOS ---

  context 'when redemption is successful and constraints are met' do
    let(:valid_date) { 1.day.from_now.to_date }
    # CRITICAL FIX: Ensure non-nil Time objects are provided for successful validation
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

    context 'for FIXED_AMOUNT voucher' do
      let(:voucher) { create_valid_voucher(voucher_type: :fixed_amount, voucher_value: 25.00) }

      it 'returns success, calculates gross amount, and logs the transaction' do
        expect {
          result = call_service(voucher, user, 75.00) # Net Amount
          expect(result).to be_success
          expect(result.data[:net_amount]).to eq(75.00.to_d)
          expect(result.data[:discount_applied]).to eq(25.00.to_d)
          # Implicitly checking Gross = 75 + 25 = 100
        }.to change(VoucherRedemptionLog, :count).by(1)
      end

      it 'calculates gross correctly even if net is 0 (covered by discount)' do
        # If Net is 0, Gross = Net + Discount = 0 + 25 = 25.
        # This implies the original bill was 25.
        result = call_service(voucher, user, 0.00) 
        expect(result).to be_success
        expect(result.data[:net_amount]).to eq(0.00.to_d)
        expect(result.data[:discount_applied]).to eq(25.00.to_d) 
      end
    end

    context 'for PERCENTAGE voucher' do
      let(:voucher) { create_valid_voucher(voucher_type: :percentage, voucher_value: 10) }

      it 'returns success and calculates gross amount from net' do
        # Net = 270. Gross = 270 / 0.9 = 300.
        result = call_service(voucher, user, 270.00)
        expect(result).to be_success
        expect(result.data[:net_amount]).to eq(270.00.to_d)
        expect(result.data[:discount_applied]).to eq(30.00.to_d) # 300 - 270
      end

      it 'handles 100% discount edge case' do
        # If 100% discount, Net should be 0.
        # Gross = Net / (1-1) -> Error handled.
        # We fallback to Gross = Net.
        over_100_voucher = create_valid_voucher(voucher_type: :percentage, voucher_value: 100)
        result = call_service(over_100_voucher, user, 0.00)
        expect(result).to be_success
        expect(result.data[:net_amount]).to eq(0.00.to_d)
        # Discount is 0 because we can't calculate infinite gross.
        expect(result.data[:discount_applied]).to eq(0.00.to_d) 
      end
    end

    context 'for FREE_ITEM voucher' do
      let(:voucher) { create_valid_voucher(voucher_type: :free_item, voucher_value: 0) }

      it 'returns success with a 0.00 discount applied' do
        result = call_service(voucher, user, 10.00)
        expect(result).to be_success
        expect(result.data[:net_amount]).to eq(10.00.to_d)
        expect(result.data[:discount_applied]).to eq(0.00.to_d)
      end
    end

    it 'updates global and per-user counts correctly' do
      voucher = create_valid_voucher(total_redemption_available: 5, max_redemptions_per_user: 2)

      # 1st Redemption
      result = nil # Initialize result for later checking
      expect { result = call_service(voucher, user) }.to change { voucher.reload.redeemed_count }.by(1)

      # Add explicit success check with diagnostics, as rollback implies failure
      expect(result).to be_success, "Service failed during successful redemption check. Error: #{result.error}"

      usage = VoucherUsage.find_by(redeemer: user, voucher: voucher)
      expect(usage.redemption_count).to eq(1)

      # 2nd Redemption
      result = nil # Reset result
      expect { result = call_service(voucher, user) }.to change { voucher.reload.redeemed_count }.by(1)
      expect(result).to be_success, "Service failed during second redemption check. Error: #{result.error}"
      expect(usage.reload.redemption_count).to eq(2)
    end
  end

  # --- VALIDATION FAILURE SCENARIOS (Testing Rollback) ---

  context 'when constraints are violated' do
    let(:valid_date) { 1.day.from_now.to_date }
    let(:valid_start_time) { Time.zone.parse('00:00:00') }
    let(:valid_end_time) { Time.zone.parse('23:59:59') }

    # Global Limit Check
    it 'fails redemption when global limit is reached' do
      limited_voucher = create(:voucher, vendor: vendor_user, event: event, total_redemption_available: 1, end_date: valid_date, start_time: valid_start_time, end_time: valid_end_time)
      call_service(limited_voucher, create(:user)) # First redemption consumes the limit

      result = call_service(limited_voucher, create(:user)) # Second attempt by a new user

      expect(result).not_to be_success
      expect(result.error).to include('out of stock')
    end

    # Per-User Limit Check
    it 'fails redemption when user has reached their limit' do
      user_limited_voucher = create(:voucher, vendor: vendor_user, event: event, max_redemptions_per_user: 1, end_date: valid_date, start_time: valid_start_time, end_time: valid_end_time)
      call_service(user_limited_voucher, user) # First redemption

      result = call_service(user_limited_voucher, user) # Second attempt by same user

      expect(result).not_to be_success
      expect(result.error).to include('personal limit')
    end

    # Time/Date Check (Expired)
    it 'fails redemption if the voucher is expired' do
      # Note: This voucher is created with a past end_date/time
      expired_voucher = create(:voucher, vendor: vendor_user, event: event, end_date: 1.day.ago.to_date, start_time: valid_start_time, end_time: valid_end_time)
      result = call_service(expired_voucher)

      expect(result).not_to be_success
      expect(result.error).to include('expired')
    end

    # Time/Date Check (Future Start)
    it 'fails redemption if the start date is in the future' do
      # Note: Voucher starts tomorrow
      future_voucher = create(:voucher, vendor: vendor_user, event: event, start_date: 1.day.from_now.to_date, end_date: 2.days.from_now.to_date, start_time: valid_start_time, end_time: valid_end_time)
      result = call_service(future_voucher)

      expect(result).not_to be_success
      expect(result.error).to include('not yet active')
    end

    # Transaction Rollback Check (Crucial!)
    it 'does NOT update counts or log a transaction on validation failure' do
      limited_voucher = create(:voucher, vendor: vendor_user, event: event, total_redemption_available: 1, end_date: valid_date, start_time: valid_start_time, end_time: valid_end_time)
      call_service(limited_voucher, create(:user)) # First redemption consumes the limit

      expect {
        call_service(limited_voucher, create(:user)) # This call should fail and rollback
      }.to not_change(VoucherRedemptionLog, :count) # Check 1: Log count should not increase
       .and(not_change { limited_voucher.reload.redeemed_count }) # Check 2: Global count should not change
    end
  end
end
