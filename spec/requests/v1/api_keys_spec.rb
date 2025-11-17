require 'swagger_helper'

# =========================================================================
# REUSABLE SCHEMAS (Defined as Global Constants) 💡
# =========================================================================

# Standard error schema for 401 (from Authenticable concern)
UNAUTHORIZED_ERROR_SCHEMA = {
  type: :object,
  properties: {
    success: { type: :boolean, description: 'Success flag' },
    message: { type: :string, description: 'Error message' },
    errors: { type: :array, description: 'Error details' }
  },
  required: ['success', 'message', 'errors']
}.freeze

# Standard error schema for 403, 404 (from controller)
SIMPLE_ERROR_SCHEMA = {
  type: :object,
  properties: {
    error: { type: :string, description: 'Error message' }
  },
  required: ['error']
}.freeze

# Standard error schema for 422 (validation errors)
VALIDATION_ERROR_SCHEMA = {
  type: :object,
  properties: {
    errors: {
      type: :array,
      description: 'Validation errors',
      items: { type: :string }
    }
  },
  required: ['errors']
}.freeze

# Schema for API Key representation (GET /v1/api_keys)
API_KEY_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer },
    name: { type: :string, nullable: true },
    last_used_at: { type: :string, format: :date_time, nullable: true },
    created_at: { type: :string, format: :date_time }
  },
  required: ['id', 'created_at']
}.freeze

# Schema for API Key creation response (POST /v1/api_keys)
API_KEY_CREATE_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer },
    name: { type: :string, nullable: true },
    raw_key: { type: :string, description: 'The raw API key - save this securely, it will not be shown again' },
    message: { type: :string }
  },
  required: ['id', 'raw_key', 'message']
}.freeze

RSpec.describe 'V1::ApiKeys', type: :request do
  let!(:org_owner) { create(:org_owner) }
  let!(:organizer_user) { create(:organizer_user) }
  let!(:member_user) { create(:member_user) }

  let(:org_owner_token) { JwtService.generate_tokens(org_owner)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # Setup existing API keys for testing
  let!(:org_owner_api_key) do
    api_key = org_owner.api_keys.create!(name: "Production Key")
    @org_owner_raw_key = api_key.raw_key
    api_key
  end

  let!(:organizer_api_key) do
    api_key = organizer_user.api_keys.create!(name: "Test Key")
    @organizer_raw_key = api_key.raw_key
    api_key
  end

  # =========================================================================
  # GET /v1/api_keys (Index - List API Keys)
  # =========================================================================

  path '/v1/api_keys' do
    get 'Lists all API keys for the authenticated user' do
      tags 'API Keys'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      # Success (Org Owner)
      response '200', 'API keys retrieved successfully' do
        let(:Authorization) { "Bearer #{org_owner_token}" }

        schema type: :array, items: API_KEY_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
          expect(json.length).to be >= 1

          # Should include the org_owner's API key
          api_key_ids = json.map { |key| key['id'] }
          expect(api_key_ids).to include(org_owner_api_key.id)

          # Should NOT include other users' keys (only their own)
          expect(api_key_ids).not_to include(organizer_api_key.id)

          # Check that name is included
          first_key = json.first
          expect(first_key).to have_key('name')
          expect(first_key['name']).to eq('Production Key')
        end
      end

      # Forbidden (Organizer - not org_owner)
      response '403', 'Forbidden (Only org_owner can manage API keys)' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        schema SIMPLE_ERROR_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to be_present
        end
      end

      # Forbidden (Member - not org_owner)
      response '403', 'Forbidden (Member cannot access)' do
        let(:Authorization) { "Bearer #{member_token}" }

        schema SIMPLE_ERROR_SCHEMA

        run_test!
      end

      # Unauthorized (Empty Token)
      response '401', 'Unauthorized (Empty token)' do
        let(:Authorization) { 'Bearer ' }

        schema UNAUTHORIZED_ERROR_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Unauthorized')
        end
      end

      # Unauthorized (Invalid Token)
      response '401', 'Unauthorized (Invalid token)' do
        let(:Authorization) { 'Bearer invalid_token_xyz' }

        schema UNAUTHORIZED_ERROR_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Unauthorized')
        end
      end
    end

    # =========================================================================
    # POST /v1/api_keys (Create - Generate New API Key)
    # =========================================================================

    post 'Creates a new API key for the authenticated user' do
      tags 'API Keys'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'
      parameter name: :api_key_data, in: :body, required: false, schema: {
        type: :object,
        properties: {
          name: {
            type: :string,
            example: 'My Production API Key',
            description: 'Optional: A descriptive name for the API key'
          }
        }
      }

      # Success (Org Owner with name)
      response '201', 'API key created successfully with name' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:api_key_data) { { name: 'My New API Key' } }

        schema API_KEY_CREATE_SCHEMA

        run_test! do |response|
          json = JSON.parse(response.body)

          # Should return the raw key
          expect(json['raw_key']).to be_present
          expect(json['raw_key'].length).to eq(64) # 32 bytes hex = 64 characters

          # Should return the name
          expect(json['name']).to eq('My New API Key')

          # Should have warning message
          expect(json['message']).to include('SAVE THIS KEY')

          # Should have an ID
          expect(json['id']).to be_present

          # Verify the key was saved to database
          api_key = ApiKey.find(json['id'])
          expect(api_key).to be_present
          expect(api_key.user_id).to eq(org_owner.id)
          expect(api_key.is_active).to be true
          expect(api_key.name).to eq('My New API Key')

          # Verify we can authenticate with the raw key
          authenticated_user = ApiKey.authenticate_by_key(json['raw_key'])
          expect(authenticated_user).to eq(org_owner)
        end
      end

      # Success (Org Owner without name - name is optional)
      response '201', 'API key created successfully without name' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:api_key_data) { {} }

        schema API_KEY_CREATE_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['raw_key']).to be_present
          expect(json['name']).to be_nil

          # Verify we can authenticate with the raw key
          authenticated_user = ApiKey.authenticate_by_key(json['raw_key'])
          expect(authenticated_user).to eq(org_owner)
        end
      end

      # Validation Error (Name too long)
      response '422', 'Unprocessable Entity (Name too long)' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:api_key_data) { { name: 'a' * 256 } } # 256 characters, exceeds 255 limit

        schema VALIDATION_ERROR_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['errors']).to be_present
          expect(json['errors'].join).to include('too long')
        end
      end

      # Forbidden (Organizer - not org_owner)
      response '403', 'Forbidden (Only org_owner can create API keys)' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:api_key_data) { { name: 'Test Key' } }

        schema SIMPLE_ERROR_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to be_present
        end
      end

      # Forbidden (Member - not org_owner)
      response '403', 'Forbidden (Member cannot create API keys)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:api_key_data) { {} }

        schema SIMPLE_ERROR_SCHEMA

        run_test!
      end

      # Unauthorized (Empty Token)
      response '401', 'Unauthorized (Empty token)' do
        let(:Authorization) { 'Bearer ' }
        let(:api_key_data) { {} }

        schema UNAUTHORIZED_ERROR_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Unauthorized')
        end
      end
    end
  end

  # =========================================================================
  # DELETE /v1/api_keys/:id (Destroy - Revoke API Key)
  # =========================================================================

  path '/v1/api_keys/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'API Key ID'

    delete 'Revokes (deactivates) an API key' do
      tags 'API Keys'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT token'

      # Success (Org Owner deletes their own key)
      response '204', 'API key revoked successfully' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { org_owner_api_key.id }

        run_test! do
          # Verify the key was deactivated (not deleted)
          api_key = ApiKey.find(id)
          expect(api_key.is_active).to be false

          # Verify authentication no longer works
          authenticated_user = ApiKey.authenticate_by_key(@org_owner_raw_key)
          expect(authenticated_user).to be_nil
        end
      end

      # Not Found (Invalid API Key ID)
      response '404', 'API key not found' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { 99999 }

        schema SIMPLE_ERROR_SCHEMA

        run_test!
      end

      # Not Found (User tries to delete another user's key)
      response '404', 'Cannot access another user\'s API key' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { organizer_api_key.id } # Trying to delete organizer's key

        schema SIMPLE_ERROR_SCHEMA

        run_test! do
          # Verify the organizer's key was NOT affected
          api_key = ApiKey.find(organizer_api_key.id)
          expect(api_key.is_active).to be true
        end
      end

      # Forbidden (Organizer - not org_owner)
      response '403', 'Forbidden (Only org_owner can revoke API keys)' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { organizer_api_key.id }

        schema SIMPLE_ERROR_SCHEMA

        run_test!
      end

      # Not Found (Member trying to access org_owner's key)
      response '404', 'Not Found (Member cannot access org_owner key)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { org_owner_api_key.id }

        schema SIMPLE_ERROR_SCHEMA

        run_test! do
          # Member doesn't have access to org_owner's key, so gets 404
          # (set_api_key filters by current_user.api_keys)
        end
      end

      # Unauthorized (Empty Token)
      response '401', 'Unauthorized (Empty token)' do
        let(:Authorization) { 'Bearer ' }
        let(:id) { org_owner_api_key.id }

        schema UNAUTHORIZED_ERROR_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['message']).to eq('Unauthorized')
        end
      end
    end
  end

  # =========================================================================
  # BONUS: Test API Key Authentication (Using API Key instead of JWT)
  # =========================================================================

  describe 'API Key Authentication' do
    context 'when using API key to access protected endpoints' do
      it 'successfully authenticates with a valid API key' do
        # Create an event to test access
        event = create(:event, title: "Test Event")

        # Make a request using the raw API key (no Bearer prefix)
        get "/v1/events/#{event.id}", headers: {
          'Authorization' => @org_owner_raw_key,
          'Content-Type' => 'application/json'
        }

        expect(response).to have_http_status(:success)
      end

      it 'rejects an invalid API key' do
        event = create(:event, title: "Test Event")

        get "/v1/events/#{event.id}", headers: {
          'Authorization' => 'invalid_api_key_string_1234567890abcdef',
          'Content-Type' => 'application/json'
        }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'rejects a revoked API key' do
        event = create(:event, title: "Test Event")

        # Revoke the key
        org_owner_api_key.revoke!

        # Try to use the revoked key
        get "/v1/events/#{event.id}", headers: {
          'Authorization' => @org_owner_raw_key,
          'Content-Type' => 'application/json'
        }

        expect(response).to have_http_status(:unauthorized)
      end

      it 'updates last_used_at timestamp on successful authentication' do
        event = create(:event, title: "Test Event")

        # Record the current last_used_at
        original_last_used = org_owner_api_key.last_used_at

        # Wait a moment to ensure timestamp difference
        sleep 0.1

        # Make a request with the API key
        get "/v1/events/#{event.id}", headers: {
          'Authorization' => @org_owner_raw_key,
          'Content-Type' => 'application/json'
        }

        expect(response).to have_http_status(:success)

        # Verify last_used_at was updated
        org_owner_api_key.reload
        expect(org_owner_api_key.last_used_at).to be > (original_last_used || 1.minute.ago)
      end
    end
  end
end
