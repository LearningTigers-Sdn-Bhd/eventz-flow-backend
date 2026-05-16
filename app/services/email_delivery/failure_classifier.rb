class EmailDelivery::FailureClassifier
  def self.call(error, now: Time.current)
    new(error, now: now).call
  end

  def initialize(error, now:)
    @error = error
    @now = now
  end

  def call
    {
      failure_reason: failure_reason,
      last_error: @error.message,
      next_retry_at: next_retry_at
    }
  end

  private

  def failure_reason
    message = @error.message.to_s.downcase

    return 'provider_daily_limit' if message.include?('daily') && message.include?('limit')
    return 'rate_limit' if @error.is_a?(Resend::Error::RateLimitExceededError)
    return 'invalid_recipient' if invalid_recipient_message?(message)
    return 'provider_error' if @error.is_a?(Resend::Error::ServerError)
    return 'network_timeout' if @error.is_a?(Net::OpenTimeout) || @error.is_a?(Net::ReadTimeout)

    'unknown'
  end

  def next_retry_at
    case failure_reason
    when 'provider_daily_limit'
      @now.tomorrow.beginning_of_day + 1.hour
    when 'rate_limit'
      retry_after = @error.respond_to?(:retry_after) ? @error.retry_after : nil
      @now + (retry_after.presence || 15.minutes)
    when 'provider_error', 'network_timeout'
      @now + 15.minutes
    end
  end

  def invalid_recipient_message?(message)
    message.include?('invalid') && (message.include?('to') || message.include?('recipient') || message.include?('email'))
  end
end
