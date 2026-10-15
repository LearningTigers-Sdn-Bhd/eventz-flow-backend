# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiIntegrations::ErrorAnalyzer, type: :service do
  let(:integration) { AiIntegration.create!(provider: 'OpenRouter', api_url: 'https://provider.example.com/v1', api_key: 'secret') }
  let!(:model) { AiModel.create!(ai_integration: integration, model_id: 'm-1', display_name: 'Model 1', is_default: true) }
  let(:failed_activity) { double('UserActivity', result: 'failed', path: '/v1/test', http_method: 'GET', details: {}, metadata: {}) }

  it 'rejects non-HTTPS provider URLs before making a request' do
    integration.update_columns(api_url: 'http://provider.example.com/v1')

    expect do
      described_class.call(failed_activity)
    end.to raise_error(described_class::Error, /HTTPS/)
  end

  it 'rejects loopback provider URLs before making a request' do
    integration.update!(api_url: 'https://127.0.0.1/v1')
    allow(Net::HTTP).to receive(:start).and_raise('network request should not be attempted')

    expect do
      described_class.call(failed_activity)
    end.to raise_error(described_class::Error, /private or local network/)
  end

  it 'rejects private provider URLs before making a request' do
    integration.update!(api_url: 'https://10.0.0.1/v1')
    allow(Net::HTTP).to receive(:start).and_raise('network request should not be attempted')

    expect do
      described_class.call(failed_activity)
    end.to raise_error(described_class::Error, /private or local network/)
  end
end
