require 'swagger_helper'

RSpec.describe 'V1::ApiKeys', type: :request do
  # --- Setup Users ---
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:member_user) { create(:member_user) }

  # --- Setup Tokens ---
  let(:org_owner_token) { JsonWebToken.encode(user_id: org_owner_user.id) }
  let(:manager_token) { JsonWebToken.encode(user_id: manager_user.id) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }

  # --- Setup Existing API Keys ---
  let!(:org_owner_api_key) do
    api_key = org_owner_user.api_keys.create!(name: "Production Key")
    # Store the raw key for testing (normally only shown once at creation)
    @org_owner_raw_key = api_key.raw_key
    api_key
  end

  let!(:manager_api_key) do
    api_key = manager_user.api_keys.create!(name: "Test Key")
    @manager_raw_key = api_key.raw_key
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

      # 1. Success (Org Owner)
      response '200', 'API keys retrieved successfully' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        
        schema type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string, nullable: true },
              last_used_at: { type: :string, format: :date_time, nullable: true },
              created_at: { type: :string, format: :date_time }
            },
            required: ['id', 'created_at']
          }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json).to be_an(Array)
          expect(json.length).to be >= 1
          
          # Should include the org_owner's API key
          api_key_ids = json.map { |key| key['id'] }
          expect(api_key_ids).to include(org_owner_api_key.id)
          
          # Should NOT include other users' keys (only their own)
          expect(api_key_ids).not_to include(manager_api_key.id)
          
          # Check that name is included
          first_key = json.first
          expect(first_key).to have_key('name')
          expect(first_key['name']).to eq('Production Key')
        end
      end

      # 2. Forbidden (Manager - not org_owner)
      response '403', 'Forbidden (Only org_owner can manage API keys)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to be_present
        end
      end

      # 3. Forbidden (Member - not org_owner)
      response '403', 'Forbidden (Member cannot access)' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end

      # 4. Unauthorized (Missing/Empty Token)
      response '401', 'Unauthorized (Empty token)' do
        let(:Authorization) { 'Bearer ' }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Unauthorized')
        end
      end

      # 5. Unauthorized (Invalid Token)
      response '401', 'Unauthorized (Invalid token)' do
        let(:Authorization) { 'Bearer invalid_token_xyz' }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Unauthorized')
        end
      end
    end
  end

  # =========================================================================
  # POST /v1/api_keys (Create - Generate New API Key)
  # =========================================================================

  path '/v1/api_keys' do
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

      # 1. Success (Org Owner with name)
      response '201', 'API key created successfully with name' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:api_key_data) { { name: 'My New API Key' } }
        
        schema type: :object,
          properties: {
            id: { type: :integer },
            name: { type: :string },
            raw_key: { type: :string, description: 'The raw API key - save this securely, it will not be shown again' },
            message: { type: :string }
          },
          required: ['id', 'raw_key', 'message']
        
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
          expect(api_key.user_id).to eq(org_owner_user.id)
          expect(api_key.is_active).to be true
          expect(api_key.name).to eq('My New API Key')
          
          # Verify we can authenticate with the raw key
          authenticated_user = ApiKey.authenticate_by_key(json['raw_key'])
          expect(authenticated_user).to eq(org_owner_user)
        end
      end

      # 2. Success (Org Owner without name - name is optional)
      response '201', 'API key created successfully without name' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:api_key_data) { {} }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['raw_key']).to be_present
          expect(json['name']).to be_nil
          
          # Verify we can authenticate with the raw key
          authenticated_user = ApiKey.authenticate_by_key(json['raw_key'])
          expect(authenticated_user).to eq(org_owner_user)
        end
      end

      # 3. Validation Error (Name too long)
      response '422', 'Unprocessable Entity (Name too long)' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:api_key_data) { { name: 'a' * 256 } } # 256 characters, exceeds 255 limit
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['errors']).to be_present
          expect(json['errors'].join).to include('too long')
        end
      end

      # 4. Forbidden (Manager - not org_owner)
      response '403', 'Forbidden (Only org_owner can create API keys)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:api_key_data) { { name: 'Test Key' } }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to be_present
        end
      end

      # 5. Forbidden (Member - not org_owner)
      response '403', 'Forbidden (Member cannot create API keys)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:api_key_data) { {} }
        run_test!
      end

      # 6. Unauthorized (Empty Token)
      response '401', 'Unauthorized (Empty token)' do
        let(:Authorization) { 'Bearer ' }
        let(:api_key_data) { {} }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Unauthorized')
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

      # 1. Success (Org Owner deletes their own key)
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

      # 2. Not Found (Invalid API Key ID)
      response '404', 'API key not found' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { 99999 }
        run_test!
      end

      # 3. Not Found (User tries to delete another user's key)
      response '404', 'Cannot access another user\'s API key' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { manager_api_key.id } # Trying to delete manager's key
        
        run_test! do
          # Verify the manager's key was NOT affected
          api_key = ApiKey.find(manager_api_key.id)
          expect(api_key.is_active).to be true
        end
      end

      # 4. Forbidden (Manager - not org_owner)
      response '403', 'Forbidden (Only org_owner can revoke API keys)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { manager_api_key.id }
        run_test!
      end

      # 5. Not Found (Member trying to access org_owner's key)
      response '404', 'Not Found (Member cannot access org_owner key)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { org_owner_api_key.id }
        
        run_test! do
          # Member doesn't have access to org_owner's key, so gets 404
          # (set_api_key filters by current_user.api_keys)
        end
      end

      # 6. Unauthorized (Empty Token)
      response '401', 'Unauthorized (Empty token)' do
        let(:Authorization) { 'Bearer ' }
        let(:id) { org_owner_api_key.id }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to eq('Unauthorized')
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
