require 'rails_helper'

RSpec.describe AiIntegrations::AvailableModelsFetcher, type: :service do
  let(:api_key) { 'secret' }

  def integration_for(api_url)
    AiIntegration.new(api_url: api_url, api_key: api_key)
  end

  it 'rejects non-HTTPS provider URLs before making a request' do
    expect do
      described_class.call(integration_for('http://provider.example.com/v1'))
    end.to raise_error(described_class::Error, /HTTPS/)
  end

  it 'rejects loopback provider URLs before making a request' do
    allow(Net::HTTP).to receive(:start).and_raise('network request should not be attempted')

    expect do
      described_class.call(integration_for('https://127.0.0.1/v1'))
    end.to raise_error(described_class::Error, /private or local network/)
  end

  it 'rejects private provider URLs before making a request' do
    allow(Net::HTTP).to receive(:start).and_raise('network request should not be attempted')

    expect do
      described_class.call(integration_for('https://10.0.0.1/v1'))
    end.to raise_error(described_class::Error, /private or local network/)
  end
end
