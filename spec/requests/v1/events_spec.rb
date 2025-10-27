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
    published: { type: :boolean, example: true },
    visibility: { type: :boolean, example: true }
  },
  required: ['id', 'title', 'status', 'start_date', 'end_date', 'payment_status', 'price', 'published', 'visibility']
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
  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:manager_token) { JwtService.generate_tokens(manager_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

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
    event = create(:event, title: "Unpaid Event", payment_status: :unpaid, published: false, visibility: true)
    create(:event_assignment, role: :event_admin, event: event, user: manager_user)
    event
  end

  let!(:event_paid) do
    event = create(:event, title: "Paid Event", payment_status: :paid, published: false, visibility: true)
    create(:event_assignment, role: :event_admin, event: event, user: manager_user)
    event
  end

  let!(:event_public) do
    event = create(:event, title: "Public Event", payment_status: :paid, published: true, visibility: true)
    create(:event_assignment, role: :event_admin, event: event, user: manager_user)
    event
  end

  let!(:event_private) do
    event = create(:event, title: "Private Event", payment_status: :paid, published: true, visibility: false)
    create(:event_assignment, role: :event_admin, event: event, user: org_owner_user)
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
          end_date: { type: :string, format: :date_time },
          visibility: { type: :boolean },
          event_admin_id: { type: :integer, description: 'Optional: User ID to assign as event admin. Defaults to current user if not provided.' }
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

      # 3. Success (With event_admin_id)
      response '201', 'Event created with specific event admin' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:event) do
          {
            event: event_attributes.merge(
              title: 'Event with Admin',
              price: 100.00,
              start_date: Time.current + 1.hour,
              end_date: Time.current + 2.hours,
              event_admin_id: manager_user.id
            )
          }
        end

        schema EVENT_SCHEMA

        run_test! do |response|
          json = JSON.parse(response.body)
          created_event = Event.find(json['id'])
          # Verify the manager_user was assigned as event admin
          expect(created_event.event_assignments.where(user_id: manager_user.id, role: 'event_admin').exists?).to be true
        end
      end

      # 4. Forbidden (Member JWT)
      response '403', 'Forbidden (Not Org Owner or Manager)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event) { valid_create_params }
        run_test!
      end

      # 5. Unauthorized (Missing Token)
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

      # 1. Success (Org Owner - sees ALL events)
      response '200', 'Org Owner sees all events' do
        let(:Authorization) { "Bearer #{org_owner_token}" }

        before { event_unpaid.reload; event_paid.reload; event_public.reload; event_private.reload }

        schema type: :array, items: EVENT_INDEX_ITEM_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          # Org Owner sees ALL events (unpaid, paid, public, private)
          expect(json.count).to eq(4)
        end
      end

      # 2. Success (Manager - sees only assigned events with visibility: true)
      response '200', 'Manager sees only assigned visible events' do
        let(:Authorization) { "Bearer #{manager_token}" }

        before { event_unpaid.reload; event_paid.reload; event_public.reload }

        schema type: :array, items: EVENT_INDEX_ITEM_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          # Manager is admin on 3 events (unpaid, paid, public), all with visibility: true
          # Manager does NOT see event_private (visibility: false)
          expect(json.count).to eq(3)
        end
      end

      # 3. Success (Member User - Should see nothing if not assigned)
      response '200', 'Empty list for member user (no assigned events)' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test! do
          json = JSON.parse(response.body)
          # Member user has no event assignments, so sees 0 events
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

      # 3. Success (Public event - published AND visible)
      response '200', 'Public event viewable by anyone' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { event_public.id }

        before do
          # Ensure the event is truly public
          event_public.update!(published: true, visibility: true)
        end

        schema EVENT_SCHEMA

        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['title']).to eq('Public Event')
        end
      end

      # 4. Forbidden (Private event - published but NOT visible, and user is not staff)
      response '403', 'Private event not viewable by non-staff' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { event_private.id }
        run_test!
      end

      # 5. Success (Private event viewable by Org Owner who is staff)
      response '200', 'Private event viewable by org owner' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:id) { event_private.id }

        schema EVENT_SCHEMA
        run_test!
      end

      # 6. Not Found
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
          status: { type: :string, enum: ['draft', 'published', 'canceled'] },
          visibility: { type: :boolean }
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
