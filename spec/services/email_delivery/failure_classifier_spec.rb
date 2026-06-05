require 'rails_helper'

RSpec.describe EmailDelivery::FailureClassifier do
  describe '.call' do
    it 'classifies Resend rate limit errors' do
      error = Resend::Error::RateLimitExceededError.new('Too many requests', 429, {})

      result = described_class.call(error)

      expect(result[:failure_reason]).to eq('rate_limit')
      expect(result[:next_retry_at]).to be_present
    end

    it 'classifies daily limit messages separately' do
      error = Resend::Error::RateLimitExceededError.new('Daily email limit reached', 429, {})

      result = described_class.call(error)

      expect(result[:failure_reason]).to eq('provider_daily_limit')
      expect(result[:next_retry_at]).to be > Time.current
    end

    it 'classifies invalid recipient provider errors' do
      error = Resend::Error::InvalidRequestError.new('Invalid `to` field', 422, {})

      result = described_class.call(error)

      expect(result[:failure_reason]).to eq('invalid_recipient')
      expect(result[:next_retry_at]).to be_nil
    end

    it 'classifies network timeouts as transient' do
      result = described_class.call(Net::OpenTimeout.new('execution expired'))

      expect(result[:failure_reason]).to eq('network_timeout')
      expect(result[:next_retry_at]).to be_present
    end
  end
end
