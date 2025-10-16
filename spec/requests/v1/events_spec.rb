# events_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Events', type: :request do
  # --- Setup Users ---
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:member_user) { create(:member_user) }

  # --- Setup Tokens ---
  let(:org_owner_token) { JsonWebToken.encode(user_id: org_owner_user.id) }
  let(:manager_token) { JsonWebToken.encode(user_id: manager_user.id) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }

  # --- SETUP API KEYS FOR PROGRAMMATIC ACCESS (NEW) ---
  # NOTE: ApiKey.create_key_for_user returns the raw (unhashed) key string
  let!(:manager_api_key) { ApiKey.create_key_for_user(manager_user) }
  let!(:org_owner_api_key) { ApiKey.create_key_for_user(org_owner_user) }
  
  # --- Setup Event Data ---
  let(:event_attributes) { attributes_for(:event) }
  let(:valid_create_params) do
    {
      event: event_attributes.merge(
        title: 'New Event Title',
        price: 100.00,
        start_date: Time.current + 1.hour,
        end_date: Time.current + 2.hours
      )
    }
  end
  let(:update_params) { { event: { title: 'Updated Event Title' } } }

  # --- Create Events (Managed by manager_user) ---
  let!(:event_unpaid) do
    event = create(:event, title: "Unpaid Event", payment_status: :unpaid)
    create(:event_admin, event: event, user: manager_user)
    event
  end
  
  let!(:event_paid) do
    event = create(:event, title: "Paid Event", payment_status: :paid)
    create(:event_admin, event: event, user: manager_user)
    event
  end

  # =========================================================================
  # POST /v1/events (Creation) & GET /v1/events (Index)
  # =========================================================================

  path '/v1/events' do
    
    # --- POST - Create ---
    post 'Creates a new event (ORG_OWNER ONLY)' do
      tags 'Events'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      # UPDATED: Description now reflects dual authentication support
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      parameter name: :event, in: :body, schema: {
        type: :object,
        properties: {
          title: { type: :string },
          description: { type: :string },
          price: { type: :number, format: :float },
          start_date: { type: :string, format: :date_time },
          end_date: { type: :string, format: :date_time }
        },
        required: ['title']
      }

      # 1. Existing Test: JWT
      response '201', 'Event created by Org Owner (JWT)' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:event) { valid_create_params }
        run_test!
      end

      # 2. ADDED Test: API Key
      response '201', 'Event created by Org Owner (API Key)' do
        # Passing the raw API Key in the Authorization header
        let(:Authorization) { org_owner_api_key } 
        let(:event) { valid_create_params }
        run_test!
      end

      # 3. Existing Test: Forbidden (Manager JWT)
      response '403', 'Forbidden (Not Org Owner)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:event) { valid_create_params }
        run_test! do
          expect(Event.count).to eq(2)
        end
      end

      # 4. Existing Test: Unauthorized (Missing Token)
      response '401', 'Unauthorized (Missing Token)' do
        let(:Authorization) { 'Bearer ' }
        let(:event) { valid_create_params }
        run_test!
      end
    end
    
    # --- GET - Index ---
    get 'Lists events managed or staffed by the user' do
      tags 'Events'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      
      # UPDATED: Description reflects dual authentication support
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Existing Test: JWT
      response '200', 'Events managed/staffed returned (JWT)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        
        before { event_unpaid.reload; event_paid.reload }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(2) 
          expect(json.map { |e| e['id'] }).to contain_exactly(event_unpaid.id, event_paid.id)
        end
        
        schema type: :array,
          items: {
            type: :object,
            properties: { id: { type: :integer }, title: { type: :string }, payment_status: { type: :string } }
          }
      end

      # 2. ADDED Test: API Key
      response '200', 'Events managed/staffed returned (API Key)' do
        let(:Authorization) { manager_api_key } 
        
        before { event_unpaid.reload; event_paid.reload }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(2) 
          expect(json.map { |e| e['id'] }).to contain_exactly(event_unpaid.id, event_paid.id)
        end
        # Schema reuse is implied by Rspec, but we keep the same output structure
      end

      # 3. Existing Test: Member User
      response '200', 'Empty list for member user' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test! do
          json = JSON.parse(response.body)
          expect(json).to be_empty
        end
      end
    end
  end

  # =========================================================================
  # GET /v1/events/:id (Show), PUT, DELETE
  # =========================================================================

  path '/v1/events/{id}' do
    # Defines the path parameter for all operations in this block
    parameter name: :id, in: :path, type: :integer, description: 'Event ID'

    # --- GET - Show ---
    get 'Retrieves a specific event' do
      tags 'Events'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      
      # UPDATED: Description reflects dual authentication support
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Existing Test: JWT
      response '200', 'Event found (JWT)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { event_paid.id }
        run_test!
        # FIX: Inline schema to avoid the JSON::Schema::SchemaError
        schema type: :object,
          properties: { 
            id: { type: :integer, example: 1 },
            title: { type: :string, example: 'Paid Event' },
            description: { type: :string, example: 'Event description.' },
            status: { type: :string, example: 'draft' },
            multiple_scans: { type: :boolean, example: false },
            start_date: { type: :string, format: :date_time },
            end_date: { type: :string, format: :date_time },
            location: { type: :string, example: 'New York City' },
            webhook_url: { type: :string, nullable: true },
            labels_data: { type: :object },
            payment_status: { type: :string, example: 'paid' },
            price: { type: :string, example: '100.0' } 
          }, 
          required: ['id', 'title', 'status', 'start_date', 'end_date', 'payment_status', 'price']
      end
      
      # 2. ADDED Test: API Key
      response '200', 'Event found (API Key)' do
        let(:Authorization) { manager_api_key }
        let(:id) { event_paid.id }
        run_test!
      end

      # 3. Existing Test: Not Found
      response '404', 'Event not found' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { 99999 }
        run_test!
      end
    end

    # --- PUT - Update ---
    put 'Updates event details' do
      tags 'Events'
      consumes 'application/json'
      security [{ BearerAuth: [] }]
      
      # UPDATED: Description reflects dual authentication support
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      parameter name: :event, in: :body, schema: {
        type: :object,
        properties: { title: { type: :string, example: 'New Title' } }
      }

      # 1. Existing Test: JWT
      response '200', 'Update successful (Manager & Paid - JWT)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { event_paid.id }
        let(:event) { update_params }
        run_test!
      end

      # 2. ADDED Test: API Key
      response '200', 'Update successful (Manager & Paid - API Key)' do
        let(:Authorization) { manager_api_key }
        let(:id) { event_paid.id }
        let(:event) { update_params }
        run_test!
      end

      # 3. Existing Test: Forbidden (Policy check)
      response '403', 'Forbidden (Manager & UNPAID)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { event_unpaid.id }
        let(:event) { update_params }
        run_test! do
          event_unpaid.reload
          expect(event_unpaid.title).not_to eq('Updated Event Title')
        end
      end
      
      # 4. Existing Test: Forbidden (Role check)
      response '403', 'Forbidden (Member user)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { event_paid.id } 
        let(:event) { update_params }
        run_test!
      end
    end

    # --- DELETE - Destroy ---
    delete 'Deletes/Archives the event' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      
      # UPDATED: Description reflects dual authentication support
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Existing Test: JWT
      response '204', 'Deletion successful (JWT)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { event_paid.id }
        run_test!
      end

      # 2. ADDED Test: API Key
      # We must create a new event here to avoid conflicts with the JWT test above,
      # as the JWT test deletes the original 'event_paid'.
      response '204', 'Deletion successful (API Key)' do
        let!(:event_to_delete) do
          event = create(:event, title: "API Key Deletion Target", payment_status: :paid)
          create(:event_admin, event: event, user: manager_user)
          event
        end
        let(:Authorization) { manager_api_key }
        let(:id) { event_to_delete.id }
        run_test!
      end

      # 3. Existing Test: Forbidden (Role check)
      response '403', 'Forbidden (Member user)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { event_paid.id }
        run_test! do
          expect(Event.exists?(event_paid.id)).to be true
        end
      end
    end
  end
end