# spec/requests/v1/events_spec.rb
require 'swagger_helper'

# =========================================================================
# REUSABLE SCHEMAS (Defined as Global Constants for RSwag compatibility)
# =========================================================================

# The full Event schema used for POST/GET/:id/PUT success responses.
EVENT_SCHEMA = {
  type: :object,
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
    price: { type: :string, example: '100.0' },
    published: { type: :boolean, example: true }
  }, 
  required: ['id', 'title', 'status', 'start_date', 'end_date', 'payment_status', 'price', 'published']
}.freeze

# The minimal schema for the index array response (/v1/events GET).
EVENT_INDEX_ITEM_SCHEMA = {
  type: :object,
  properties: { 
    id: { type: :integer }, 
    title: { type: :string }, 
    payment_status: { type: :string } 
  }
}.freeze


RSpec.describe 'V1::Events', type: :request do
  # --- Setup Users ---
  # Assuming create(:org_owner), create(:manager_user), create(:member_user) factories exist
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:member_user) { create(:member_user) }

  # --- Setup Tokens ---
  # Assuming JsonWebToken.encode exists
  let(:org_owner_token) { JsonWebToken.encode(user_id: org_owner_user.id) }
  let(:manager_token) { JsonWebToken.encode(user_id: manager_user.id) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }

  # --- SETUP API KEYS ---
  # Assuming ApiKey.create_key_for_user exists
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
  # Note: The policy now allows the manager to update both paid and unpaid events.
  let!(:event_unpaid) do
    event = create(:event, title: "Unpaid Event", payment_status: :unpaid, published: false)
    create(:event_assignment, role: :event_admin, event: event, user: manager_user)
    event
  end
  
  let!(:event_paid) do
    event = create(:event, title: "Paid Event", payment_status: :paid, published: false)
    create(:event_assignment, role: :event_admin, event: event, user: manager_user)
    event
  end

  # =========================================================================
  # POST /v1/events (Creation) & GET /v1/events (Index)
  # =========================================================================

  path '/v1/events' do
    
    # --- POST - Create ---
    post 'Creates a new event (ORG_OWNER or MANAGER ONLY)' do
      tags 'Events'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

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
        required: ['title', 'start_date', 'end_date']
      }

      # 1. Success (Org Owner JWT)
      response '201', 'Event created successfully' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:event) { valid_create_params }
        schema EVENT_SCHEMA
        run_test!
      end

      # 2. Success (API Key)
      response '201', 'Event created by API Key' do
        let(:Authorization) { org_owner_api_key }
        let(:event) { valid_create_params }
        run_test!
      end

      # 3. Forbidden (Member JWT)
      response '403', 'Forbidden (Not Org Owner or Manager)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event) { valid_create_params }
        run_test!
      end

      # 4. Unauthorized (Missing Token)
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
      
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Success (Manager)
      response '200', 'Events managed/staffed returned' do
        let(:Authorization) { "Bearer #{manager_token}" }
        
        before { event_unpaid.reload; event_paid.reload }
        
        schema type: :array, items: EVENT_INDEX_ITEM_SCHEMA 
        
        run_test! do
          json = JSON.parse(response.body)
          # Manager is admin on both events
          expect(json.count).to eq(2) 
        end
      end
      
      # 2. Success (Member User - Should see nothing but published events, and no events are published in this specific setup)
      response '200', 'Empty list for member user (no published or assigned events)' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test! do
          json = JSON.parse(response.body)
          # Assuming the created events are not published unless explicitly set
          # The policy scope shows published events OR assigned events.
          # Since event_unpaid and event_paid are published: false, the member sees 0 events.
          expect(json.count).to eq(0)
        end
      end
    end
  end

  # =========================================================================
  # GET /v1/events/:id (Show), PUT, DELETE
  # =========================================================================

  path '/v1/events/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Event ID'

    # --- GET - Show ---
    get 'Retrieves a specific event' do
      tags 'Events'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Success (JWT)
      response '200', 'Event found' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { event_paid.id }
        
        schema EVENT_SCHEMA
        run_test!
      end
      
      # 2. Success (API Key)
      response '200', 'Event found via API Key' do
        let(:Authorization) { manager_api_key }
        let(:id) { event_paid.id }
        run_test!
      end

      # 3. Not Found
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
      produces 'application/json'
      security [{ BearerAuth: [] }]
      
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'
      parameter name: :event, in: :body, schema: {
        type: :object,
        properties: { 
          title: { type: :string, example: 'New Title' },
          description: { type: :string },
          location: { type: :string },
          status: { type: :string, enum: ['draft', 'published', 'canceled'] }
        }
      }

      # 1. Success 
      response '200', 'Update successful (Manager)' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { event_paid.id }
        let(:event) { update_params }
        
        schema EVENT_SCHEMA
        run_test!
      end

      # 2. Forbidden (Policy check: Member user)
      response '403', 'Forbidden (Member user)' do
        # FIX: Changed token from manager_token to member_token
        let(:Authorization) { "Bearer #{member_token}" } 
        let(:id) { event_unpaid.id }
        let(:event) { update_params }
        run_test!
      end
    end

    # --- DELETE - Destroy ---
    delete 'Deletes/Archives the event' do
      tags 'Events'
      security [{ BearerAuth: [] }]
      
      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Success 
      response '204', 'Deletion successful' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { event_paid.id }
        run_test!
      end

      # 2. Forbidden (Member user)
      response '403', 'Forbidden (Member user)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { event_paid.id }
        run_test!
      end
    end
  end
end