require 'rails_helper'

RSpec.describe 'V1::AiIntegrations', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:other_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:headers) { { 'Authorization' => "Bearer #{jwt_token(owner)}" } }
  let(:secret) { 'super-secret-api-key' }
  let(:provider_attributes) do
    {
      provider: 'OpenRouter',
      api_url: 'https://openrouter.ai/api/v1',
      api_key: secret
    }
  end

  def create_integration(user: owner, name: 'OpenRouter')
    AiIntegration.create!(
      user: user,
      provider: name,
      api_url: "https://example.com/#{name.downcase}/v1",
      api_key: secret
    )
  end

  def parsed_body
    JSON.parse(response.body)
  end

  def expect_masked_credentials(payload = parsed_body)
    expect(payload).to include('has_api_key' => true)
    expect(payload).not_to have_key('api_key')
    expect(response.body).not_to include(secret)
  end

  describe 'GET /v1/ai_integrations' do
    it 'returns an empty list without an error when nothing is configured' do
      get '/v1/ai_integrations', headers: headers

      expect(response).to have_http_status(:ok)
      expect(parsed_body).to eq([])
    end

    it 'returns every provider with its models and masked credentials' do
      first = create_integration
      second = create_integration(name: 'OpenAI')
      first.ai_models.create!(model_id: 'cx/gpt-5.6', display_name: 'GPT 5.6')
      second.ai_models.create!(model_id: 'gpt-5.4', display_name: 'GPT 5.4')

      get '/v1/ai_integrations', headers: headers

      expect(response).to have_http_status(:ok)
      expect(parsed_body.size).to eq(2)
      expect(parsed_body.pluck('provider')).to eq(%w[OpenAI OpenRouter])
      parsed_body.each { |provider| expect_masked_credentials(provider) }
      expect(parsed_body.flat_map { |provider| provider['models'] }.pluck('model_id')).to contain_exactly(
        'cx/gpt-5.6', 'gpt-5.4'
      )
    end

    it 'forbids non-owners' do
      get '/v1/ai_integrations', headers: {
        'Authorization' => "Bearer #{jwt_token(organizer)}"
      }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /v1/ai_integrations' do
    it 'creates multiple providers for the same owner without exposing API keys' do
      post '/v1/ai_integrations', params: { ai_integration: provider_attributes }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect_masked_credentials

      post '/v1/ai_integrations', params: {
        ai_integration: provider_attributes.merge(provider: 'OpenAI')
      }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(owner.ai_integrations.count).to eq(2)
      expect_masked_credentials
    end

    it 'forbids non-owners' do
      post '/v1/ai_integrations', params: { ai_integration: provider_attributes }, headers: {
        'Authorization' => "Bearer #{jwt_token(organizer)}"
      }, as: :json

      expect(response).to have_http_status(:forbidden)
      expect(response.body).not_to include(secret)
    end

    it 'requires an HTTPS provider URL' do
      post '/v1/ai_integrations', params: {
        ai_integration: provider_attributes.merge(api_url: 'http://provider.example.com/v1')
      }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(parsed_body['errors']).to include('Api url must be a valid HTTPS URL')
    end
  end

  describe 'PATCH /v1/ai_integrations/:id' do
    it 'updates provider details while preserving a blank API key' do
      integration = create_integration

      patch "/v1/ai_integrations/#{integration.id}", params: {
        ai_integration: { provider: 'Company Gateway', api_key: '' }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(integration.reload.api_key).to eq(secret)
      expect(parsed_body['provider']).to eq('Company Gateway')
      expect_masked_credentials
    end

    it 'does not allow another owner to update the provider' do
      integration = create_integration(user: other_owner)

      patch "/v1/ai_integrations/#{integration.id}", params: {
        ai_integration: { provider: 'Stolen' }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'DELETE /v1/ai_integrations/:id' do
    it 'deletes the provider and its models' do
      integration = create_integration
      integration.ai_models.create!(model_id: 'cx/gpt-5.6', display_name: 'GPT 5.6')

      expect do
        delete "/v1/ai_integrations/#{integration.id}", headers: headers
      end.to change(AiModel, :count).by(-1).and change(AiIntegration, :count).by(-1)

      expect(response).to have_http_status(:no_content)
    end
  end

  describe 'provider models' do
    let(:integration) { create_integration }

    it 'creates multiple models with required identifiers and optional display names' do
      post "/v1/ai_integrations/#{integration.id}/ai_models", params: {
        ai_model: { model_id: 'cx/gpt-5.6', model_name: 'GPT 5.6' }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(parsed_body).to include(
        'model_id' => 'cx/gpt-5.6',
        'model_name' => 'GPT 5.6',
        'is_default' => true
      )

      post "/v1/ai_integrations/#{integration.id}/ai_models", params: {
        ai_model: { model_id: 'anthropic/claude-sonnet', model_name: '' }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(parsed_body['model_name']).to eq('')
      expect(parsed_body['is_default']).to be(false)
      expect(integration.ai_models.count).to eq(2)
    end

    it 'rejects a model without a model ID' do
      post "/v1/ai_integrations/#{integration.id}/ai_models", params: {
        ai_model: { model_id: '', model_name: 'Unnamed model' }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'allows a model without a display name' do
      post "/v1/ai_integrations/#{integration.id}/ai_models", params: {
        ai_model: { model_id: 'provider/model-without-name', model_name: '' }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(parsed_body).to include(
        'model_id' => 'provider/model-without-name',
        'model_name' => ''
      )
    end

    it 'updates a model' do
      model = integration.ai_models.create!(model_id: 'cx/gpt-5.6', display_name: 'GPT 5.6')

      patch "/v1/ai_integrations/#{integration.id}/ai_models/#{model.id}", params: {
        ai_model: { model_id: 'cx/gpt-5.7', model_name: 'GPT 5.7' }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(parsed_body).to include('model_id' => 'cx/gpt-5.7', 'model_name' => 'GPT 5.7')
    end

    it 'sets exactly one default model across providers' do
      first_model = integration.ai_models.create!(model_id: 'cx/gpt-5.6', display_name: 'GPT 5.6')
      second_provider = create_integration(name: 'OpenAI')
      second_model = second_provider.ai_models.create!(model_id: 'gpt-5.4', display_name: 'GPT 5.4')

      patch "/v1/ai_integrations/#{integration.id}/ai_models/#{first_model.id}/set_default",
            headers: headers
      expect(response).to have_http_status(:ok)
      expect(owner.reload.default_ai_model).to eq(first_model)
      expect(parsed_body['is_default']).to be(true)

      patch "/v1/ai_integrations/#{second_provider.id}/ai_models/#{second_model.id}/set_default",
            headers: headers
      expect(response).to have_http_status(:ok)
      expect(owner.reload.default_ai_model).to eq(second_model)
      expect(first_model.reload).not_to be_default_for(owner)
    end

    it 'clears the default when its model is deleted' do
      model = integration.ai_models.create!(model_id: 'cx/gpt-5.6', display_name: 'GPT 5.6')
      owner.update!(default_ai_model: model)

      delete "/v1/ai_integrations/#{integration.id}/ai_models/#{model.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(owner.reload.default_ai_model).to be_nil
    end

    it 'does not allow an owner to manage another owner model' do
      foreign_provider = create_integration(user: other_owner, name: 'Foreign')
      model = foreign_provider.ai_models.create!(model_id: 'foreign/model', display_name: 'Foreign Model')

      patch "/v1/ai_integrations/#{foreign_provider.id}/ai_models/#{model.id}/set_default",
            headers: headers

      expect(response).to have_http_status(:not_found)
    end

    it 'imports selected models in one request and chooses the first model by default' do
      post "/v1/ai_integrations/#{integration.id}/ai_models/import", params: {
        ai_models: {
          models: [
            { model_id: 'gcli/grok-4.6', model_name: '' },
            { model_id: 'gcli/grok-4.6-high', model_name: 'Grok High' },
            { model_id: 'gcli/grok-4.6-high', model_name: 'Duplicate' }
          ]
        }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(parsed_body.pluck('model_id')).to contain_exactly(
        'gcli/grok-4.6', 'gcli/grok-4.6-high'
      )
      expect(parsed_body.find { |model| model['model_id'] == 'gcli/grok-4.6' }['is_default']).to be(true)
      expect(owner.reload.default_ai_model.model_id).to eq('gcli/grok-4.6')
    end

    it 'does not duplicate existing models during import' do
      existing = integration.ai_models.create!(model_id: 'gcli/grok-4.6', display_name: 'Custom Name')

      post "/v1/ai_integrations/#{integration.id}/ai_models/import", params: {
        ai_models: {
          models: [
            { model_id: 'gcli/grok-4.6', model_name: 'Provider Name' },
            { model_id: 'gcli/grok-4.6-high', model_name: '' }
          ]
        }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:created)
      expect(integration.ai_models.count).to eq(2)
      expect(existing.reload.display_name).to eq('Custom Name')
    end

    it 'does not allow another owner to import models' do
      foreign_provider = create_integration(user: other_owner, name: 'Foreign')

      post "/v1/ai_integrations/#{foreign_provider.id}/ai_models/import", params: {
        ai_models: { models: [{ model_id: 'foreign/model', model_name: '' }] }
      }, headers: headers, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /v1/ai_integrations/:id/available_models' do
    let(:integration) { create_integration }
    let(:models_url) { "#{integration.api_url}/models" }

    it 'returns normalized models from an OpenAI-compatible provider' do
      stub_request(:get, models_url)
        .with(headers: { 'Authorization' => "Bearer #{secret}" })
        .to_return(
          status: 200,
          body: {
            data: [
              { id: 'gcli/grok-4.6', name: 'Grok 4.6' },
              { id: 'gcli/grok-4.6-high' },
              { id: 'gcli/grok-4.6-high' }
            ]
          }.to_json,
          headers: { 'Content-Type' => 'application/json' }
        )

      get "/v1/ai_integrations/#{integration.id}/available_models", headers: headers

      expect(response).to have_http_status(:ok)
      expect(parsed_body).to eq([
        { 'model_id' => 'gcli/grok-4.6', 'model_name' => 'Grok 4.6' },
        { 'model_id' => 'gcli/grok-4.6-high', 'model_name' => '' }
      ])
      expect(response.body).not_to include(secret)
    end

    it 'returns a bad gateway response when the provider model request fails' do
      stub_request(:get, models_url)
        .with(headers: { 'Authorization' => "Bearer #{secret}" })
        .to_return(status: 401, body: '{"error":"invalid key"}')

      get "/v1/ai_integrations/#{integration.id}/available_models", headers: headers

      expect(response).to have_http_status(:bad_gateway)
      expect(parsed_body['message']).to eq('Unable to load available models')
      expect(response.body).not_to include(secret)
    end

    it 'does not expose another owner provider models' do
      foreign_provider = create_integration(user: other_owner, name: 'Foreign')

      get "/v1/ai_integrations/#{foreign_provider.id}/available_models", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
