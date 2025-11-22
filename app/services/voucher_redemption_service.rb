# Service Object to handle the complex business logic of redeeming a voucher.
# It ensures all limits (time, global, per-user) are respected and uses a
# transaction to guarantee atomicity.
class VoucherRedemptionService
  # Define a simple result object for clean error/success handling
  Result = Struct.new(:success?, :data, :error, keyword_init: true)

  # Class method entry point (the recommended way to call the service)
  # Usage: VoucherRedemptionService.call(voucher: ..., redeemer: ..., ...)
  def self.call(voucher:, redeemer:, vendor_id:, net_amount:)
    new(voucher:, redeemer:, vendor_id:, net_amount:).call
  end

  # Initializes the service with all required data
  def initialize(voucher:, redeemer:, vendor_id:, net_amount:)
    @voucher = voucher
    @redeemer = redeemer
    @vendor_id = vendor_id
    @net_amount = net_amount.to_d # Ensure monetary value is Decimal
  end

  # Main execution method
  def call
    # Start a database transaction: all steps must succeed, or all will roll back.
    ActiveRecord::Base.transaction do
      # 1. Run all critical validations
      check_validity!

      # 2. Calculate the discount and gross amount
      calculate_financials

      # 3. Update usage counts
      update_counts!

      # 4. Create the audit log
      log_redemption

      # Success: return the financial details
      return success_result
    end
  rescue StandardError => e
    # Catch any raised exceptions (including those from check_validity!)
    failure_result(e.message)
  end

  private

  # --- CORE VALIDATIONS (Raises exception on failure) ---

  def check_validity!
    # Check 1: Time/Date Validity
    # The 'time_is_valid?' logic now handles the possibility of missing data.
    raise "Voucher has expired or is not yet active." unless time_is_valid?

    # Check 2: Global Count Limit
    raise "Voucher is out of stock (Global limit reached)." unless global_count_is_available?

    # Check 3: Per-User Limit
    raise "User has reached their personal redemption limit." unless per_user_limit_is_available?

    # NOTE: The minimum purchase check was omitted as per user request.
  end

  def time_is_valid?
    # FIX: Ensure all required attributes are present before attempting calculation
    required_attributes = [@voucher.start_date, @voucher.end_date, @voucher.start_time, @voucher.end_time]
    return false if required_attributes.any?(&:nil?)

    now = Time.current

    begin
      # FIX: Use the robust Rails pattern to safely combine Date and Time attributes
      # into Time objects in the current time zone ('Asia/Kuala_Lumpur' in RSpec).
      start_time_in_zone = @voucher.start_time.in_time_zone(Time.zone)
      end_time_in_zone = @voucher.end_time.in_time_zone(Time.zone)

      # Combine date component with time components using .change
      start_at = @voucher.start_date.to_time.in_time_zone(Time.zone).change(
        hour: start_time_in_zone.hour,
        min: start_time_in_zone.min,
        sec: start_time_in_zone.sec
      )
      end_at   = @voucher.end_date.to_time.in_time_zone(Time.zone).change(
        hour: end_time_in_zone.hour,
        min: end_time_in_zone.min,
        sec: end_time_in_zone.sec
      )

      now.between?(start_at, end_at)
    rescue StandardError
      # Catch any remaining time-related errors during object construction or comparison
      false
    end
  end

  def global_count_is_available?
    # Use .to_i to guarantee that total_redemption_available and redeemed_count
    # are treated as integers, resolving the `undefined method '<' for nil` error
    # if database columns were nil.
    total = @voucher.total_redemption_available.to_i
    redeemed = @voucher.redeemed_count.to_i

    # True if limit is 0 (unlimited) OR if redeemed count is less than available count
    total.zero? || (redeemed < total)
  end

  def per_user_limit_is_available?
    # Use find_or_initialize_by to get the current usage record
    usage = VoucherUsage.find_or_initialize_by(redeemer: @redeemer, voucher: @voucher)

    # Use .to_i on max_redemptions_per_user to guarantee it's an integer.
    max_limit = @voucher.max_redemptions_per_user.to_i
    current_count = usage.redemption_count.to_i

    # True if limit is 0 (unlimited) OR if usage count is less than the max limit
    max_limit.zero? || (current_count < max_limit)
  end

  # --- CALCULATION ---

  def calculate_financials
    value = @voucher.voucher_value.to_d

    if @voucher.percentage?
      # Net = Gross * (1 - value/100)
      # Gross = Net / (1 - value/100)
      factor = 1 - (value / 100.0)
      
      if factor <= 0
        # Handle 100% discount or invalid > 100% discount
        # If 100% discount, we can't reverse calculate Gross from Net=0 accurately without more info.
        # Assuming Gross = Net for safety if invalid, or 0 if Net is 0.
        @gross_amount = @net_amount 
        @discount_amount = 0
      else
        @gross_amount = @net_amount / factor
        @discount_amount = @gross_amount - @net_amount
      end
    elsif @voucher.fixed_amount?
      # Gross = Net + Discount
      # Note: If the original Gross was < Discount, the Net would be 0.
      # Here we assume Gross = Net + Discount.
      @discount_amount = value
      @gross_amount = @net_amount + @discount_amount
    elsif @voucher.free_item?
      # For free item, we assume the Net Amount entered is for other items, 
      # and the "discount" is 0 in terms of the bill reduction logic here, 
      # or maybe we shouldn't calculate backwards for free items.
      # Keeping it simple:
      @gross_amount = @net_amount
      @discount_amount = 0.to_d
    else
      @gross_amount = @net_amount
      @discount_amount = 0.to_d
    end
  end

  # --- STATE CHANGES ---

  def update_counts!
    # 1. Update global count (atomic database operation)
    @voucher.increment!(:redeemed_count)

    # 2. Update per-redeemer count (atomic database operation)
    usage = VoucherUsage.find_or_create_by!(redeemer: @redeemer, voucher: @voucher)
    usage.increment!(:redemption_count)
  end

  def log_redemption
    VoucherRedemptionLog.create!(
      voucher: @voucher,
      redeemer: @redeemer,  # Polymorphic association automatically sets redeemer_type and redeemer_id
      redeemer_staff_id: @vendor_id,
      redemption_timestamp: Time.current,
      redemption_status: :completed,
      transaction_gross_amount: @gross_amount,
      discount_applied_value: @discount_amount,
      transaction_net_amount: @net_amount
    )
  end

  # --- RESULT OBJECTS ---

  def success_result
    Result.new(success?: true, data: {
      net_amount: @net_amount,
      discount_applied: @discount_amount,
      voucher_type: @voucher.voucher_type
    })
  end

  def failure_result(message)
    Result.new(success?: false, error: message)
  end
end
