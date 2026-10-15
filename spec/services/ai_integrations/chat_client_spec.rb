require 'rails_helper'
require 'webmock/rspec'

RSpec.describe AiIntegrations::ChatClient, type: :service do
  let(:integration) { AiIntegration.new(provider: 'Test', api_url: 'https://llm.example.com/v1', api_key: 'sk-secret') }
  let(:endpoint) { 'https://llm.example.com/v1/chat/completions' }

  def call(**overrides)
    described_class.call(integration:, model_id: 'test-model', system: 'be brief', user: 'hello', **overrides)
  end

  before do
    allow(AiIntegrations::NetworkGuard).to receive(:pick_safe_address).and_return('93.184.216.34')
  end

  it 'posts an OpenAI-style chat completion with the key and returns the text' do
    stub = stub_request(:post, endpoint)
           .with(headers: { 'Authorization' => 'Bearer sk-secret', 'Content-Type' => 'application/json' }) do |request|
             body = JSON.parse(request.body)
             body['model'] == 'test-model' && body['messages'].map { |m| m['role'] } == %w[system user]
           end
           .to_return(status: 200, body: { choices: [{ message: { content: 'hi there' } }] }.to_json)

    expect(call).to eq('hi there')
    expect(stub).to have_been_requested
  end

  it 'refuses non-HTTPS providers without connecting' do
    integration.api_url = 'http://llm.example.com/v1'
    expect { call }.to raise_error(described_class::Error, /HTTPS/)
  end

  it 'refuses a provider that resolves to a private address' do
    allow(AiIntegrations::NetworkGuard).to receive(:pick_safe_address)
      .and_raise(AiIntegrations::NetworkGuard::Blocked, 'Provider URL must not target a private or local network')
    expect { call }.to raise_error(described_class::Error, /private or local/)
  end

  it 'reports a provider error with its own message but never the key or prompt' do
    stub_request(:post, endpoint).to_return(status: 401, body: { error: { message: 'Incorrect API key' } }.to_json)
    expect { call }.to raise_error(described_class::Error) { |e|
      expect(e.message).to include('401', 'Incorrect API key')
      expect(e.message).not_to include('sk-secret')
      expect(e.message).not_to include('hello')
    }
  end

  it 'handles a non-JSON error page' do
    stub_request(:post, endpoint).to_return(status: 502, body: '<html>bad gateway</html>')
    expect { call }.to raise_error(described_class::Error, /\(502\)/)
  end

  it 'handles an empty answer and unreadable JSON' do
    stub_request(:post, endpoint).to_return(status: 200, body: { choices: [{ message: { content: '' } }] }.to_json)
    expect { call }.to raise_error(described_class::Error, /empty/)
    stub_request(:post, endpoint).to_return(status: 200, body: 'not json')
    expect { call }.to raise_error(described_class::Error, /unreadable/)
  end

  it 'turns timeouts and connection failures into friendly errors' do
    stub_request(:post, endpoint).to_timeout
    expect { call }.to raise_error(described_class::Error, /too long|connect/)
  end
end
