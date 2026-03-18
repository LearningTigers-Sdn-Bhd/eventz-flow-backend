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
    visibility: { type: :boolean, example: true },
    enable_exhibitor_management: { type: :boolean, example: false },
    use_seat_ticketing: { type: :boolean, example: false },
    use_wedding: { type: :boolean, example: false },
    wish_wall_setting: {
      type: :object,
      nullable: true,
      properties: {
        display_mode: { type: :string, example: 'cards' },
        animation_shape: { type: :string, nullable: true, example: 'heart' },
        animation_text: { type: :string, nullable: true, example: 'Aisyah & Faiz' },
        accent_color: { type: :string, nullable: true, example: '#F59E0B' },
        header_text_color: { type: :string, nullable: true, example: '#111827' },
        card_background_color: { type: :string, nullable: true, example: '#FFFBEB' },
        background_image_url: { type: :string, nullable: true,
                                example: '/rails/active_storage/blobs/example/test_image.png' }
      }
    }
  },
  required: %w[id title status start_date end_date payment_status price published visibility]
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

BUSINESS_MATCHING_EVENT_SCHEMA = {
  type: :array,
  items: {
    type: :object,
    properties: {
      id: { type: :integer, example: 1 },
      title: { type: :string, example: 'Match Session 1' },
      duration: { type: :integer, example: 30 },
      location: { type: :string, example: 'Virtual Link' },
      admin_email: { type: :string, example: 'match_admin@example.com' },
      admin_wa_number: { type: :string, example: '628123456789' }
    },
    required: %w[id title duration]
  }
}.freeze

RSpec.describe 'V1::Events', type: :request do
  # --- Setup Users ---
  # Assuming create(:org_owner), create(:organizer_user), create(:member_user) factories exist
  let(:org_owner_user) { create(:user, :org_owner) }
  let(:organizer_user) { create(:user, :organizer) }
  let(:member_user) { create(:user, :member) }

  # --- Setup Tokens ---
  # Assuming JsonWebToken.encode exists
  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- SETUP API KEYS ---
  # Assuming ApiKey.create_key_for_user exists
  let!(:organizer_api_key) { ApiKey.create_key_for_user(organizer_user) }
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

  # --- Create Events (Managed by organizer_user) ---
  # Note: The policy now allows the organizer to update both paid and unpaid events.
  let!(:event_unpaid) do
    event = create(:event, title: 'Unpaid Event', payment_status: :unpaid, published: false, visibility: true)
    create(:event_assignment, role: :event_admin, event: event, user: organizer_user)
    event
  end

  let!(:event_paid) do
    event = create(:event, title: 'Paid Event', payment_status: :paid, published: false, visibility: true)
    create(:event_assignment, role: :event_admin, event: event, user: organizer_user)
    event
  end

  let!(:event_public) do
    event = create(:event, title: 'Public Event', payment_status: :paid, published: true, visibility: true)
    create(:event_assignment, role: :event_admin, event: event, user: organizer_user)
    event
  end

  let!(:event_private) do
    event = create(:event, title: 'Private Event', payment_status: :paid, published: true, visibility: false)
    create(:event_assignment, role: :event_admin, event: event, user: org_owner_user)
    event
  end

  # =========================================================================
  # POST /v1/events (Creation) & GET /v1/events (Index)
  # =========================================================================

  path '/v1/events' do
    # --- POST - Create ---
    post 'Creates a new event (ORG_OWNER or ORGANIZER ONLY)' do
      tags 'Events'
      consumes 'application/json', 'multipart/form-data'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT or Raw API Key'
      parameter name: :event, in: :body, schema: {
        type: :object,
        properties: {
          title: { type: :string },
          description: { type: :string },
          price: { type: :number, format: :float },
          start_date: { type: :string, format: :date_time },
          end_date: { type: :string, format: :date_time },
          visibility: { type: :boolean },
          enable_exhibitor_management: { type: :boolean },
          use_seat_ticketing: { type: :boolean },
          use_wedding: { type: :boolean },
          event_admin_id: { type: :integer,
                            description: 'Optional: User ID to assign as event admin. Defaults to current user if not provided.' }
        },
        required: %w[title start_date end_date]
      }

      # 1. Success (Org Owner JWT)
      response '201', 'Event created successfully' do
        let(:Authorization) { "Bearer #{org_owner_token}" }
        let(:event) do
          valid_create_params.deep_merge(event: {
                                           use_wedding: true,
                                           enable_exhibitor_management: true
                                         })
        end
        schema EVENT_SCHEMA
        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['use_wedding']).to be true
          expect(json['enable_exhibitor_management']).to be true
          expect(Event.find(json['id']).use_wedding).to be true
          expect(Event.find(json['id']).enable_exhibitor_management).to be true
        end
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
              event_admin_id: organizer_user.id
            )
          }
        end

        schema EVENT_SCHEMA

        run_test! do |response|
          json = JSON.parse(response.body)
          created_event = Event.find(json['id'])
          # Verify the organizer_user was assigned as event admin
          expect(created_event.event_assignments.where(user_id: organizer_user.id,
                                                       role: 'event_admin').exists?).to be true
        end
      end

      # 4. Forbidden (Member JWT)
      response '403', 'Forbidden (Not Org Owner or Organizer)' do
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

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT or Raw API Key'
      parameter name: :archived, in: :query, type: :string, required: false,
                description: 'Set to "true" to show only archived events'
      parameter name: :full, in: :query, type: :string, required: false,
                description: 'Set to "true" to show all events including archived ones'

      # 1. Success (Org Owner - sees ALL events)
      response '200', 'Org Owner sees all events' do
        let(:Authorization) { "Bearer #{org_owner_token}" }

        before do
          event_unpaid.reload
          event_paid.reload
          event_public.reload
          event_private.reload
        end

        schema type: :array, items: EVENT_INDEX_ITEM_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          # Org Owner sees ALL events (unpaid, paid, public, private)
          expect(json.count).to eq(4)
        end
      end

      # 2. Success (Organizer - sees only assigned events with visibility: true)
      response '200', 'Organizer sees only assigned visible events' do
        let(:Authorization) { "Bearer #{organizer_token}" }

        before do
          event_unpaid.reload
          event_paid.reload
          event_public.reload
        end

        schema type: :array, items: EVENT_INDEX_ITEM_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          # Organizer is admin on 3 events (unpaid, paid, public), all with visibility: true
          # Organizer does NOT see event_private (visibility: false)
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

      # 4. Success (Show only archived events)
      response '200', 'Lists only archived events' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:archived) { 'true' }

        before do
          event_paid.archive
        end

        schema type: :array, items: EVENT_INDEX_ITEM_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          # Should only see archived events
          expect(json.count).to be >= 1
          json.each do |event|
            expect(event['deleted_at']).not_to be_nil
          end
        end
      end

      # 5. Success (Show all events including archived)
      response '200', 'Lists all events including archived' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:full) { 'true' }

        before do
          event_paid.archive
        end

        schema type: :array, items: EVENT_INDEX_ITEM_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          # Should see both active and archived events
          expect(json.count).to be >= 3
          has_archived = json.any? { |event| event['deleted_at'].present? }
          has_active = json.any? { |event| event['deleted_at'].nil? }
          expect(has_archived).to be true
          expect(has_active).to be true
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

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT or Raw API Key'

      # 1. Success (JWT)
      response '200', 'Event found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { event_paid.id }

        schema EVENT_SCHEMA
        run_test!
      end

      # 2. Success (API Key)
      response '200', 'Event found via API Key' do
        let(:Authorization) { organizer_api_key }
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
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { 99_999 }
        run_test!
      end
    end

    # --- PUT - Update ---
    put 'Updates event details' do
      tags 'Events'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT or Raw API Key'
      parameter name: :event, in: :body, schema: {
        type: :object,
        properties: {
          title: { type: :string, example: 'New Title' },
          description: { type: :string },
          location: { type: :string },
          status: { type: :string, enum: %w[draft published canceled] },
          visibility: { type: :boolean },
          use_seat_ticketing: { type: :boolean },
          use_sponsorship: { type: :boolean },
          use_wedding: { type: :boolean },
          wish_wall_background_image: { type: :string, format: :binary },
          remove_wish_wall_background_image: { type: :boolean }
        }
      }

      # 1. Success
      response '200', 'Update successful (Organizer)' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { event_paid.id }
        let(:event) do
          {
            event: {
              title: 'New Title',
              enable_exhibitor_management: true,
              use_sponsorship: true,
              use_wedding: true,
              auto_approve_wishes: true,
              wish_wall_setting_attributes: {
                display_mode: 'animation',
                animation_shape: 'butterfly',
                animation_text: 'Aisyah & Faiz',
                accent_color: '#F59E0B',
                header_text_color: '#111827',
                card_background_color: '#FFFBEB'
              }
            }
          }
        end

        schema EVENT_SCHEMA
        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['enable_exhibitor_management']).to be true
          expect(json['use_sponsorship']).to be true
          expect(json['use_wedding']).to be true
          expect(json['auto_approve_wishes']).to be true
          expect(json.dig('wish_wall_setting', 'display_mode')).to eq('animation')
          expect(json.dig('wish_wall_setting', 'animation_shape')).to eq('butterfly')
          expect(json.dig('wish_wall_setting', 'animation_text')).to eq('Aisyah & Faiz')
          expect(json.dig('wish_wall_setting', 'accent_color')).to eq('#F59E0B')
          expect(json.dig('wish_wall_setting', 'header_text_color')).to eq('#111827')
          expect(json.dig('wish_wall_setting', 'card_background_color')).to eq('#FFFBEB')
          expect(json.dig('wish_wall_setting', 'background_image_url')).to be_nil
          expect(event_paid.reload.use_wedding).to be true
          expect(event_paid.reload.enable_exhibitor_management).to be true
          expect(event_paid.reload.auto_approve_wishes).to be true
          expect(event_paid.reload.wish_wall_setting).to have_attributes(
            display_mode: 'animation',
            animation_shape: 'butterfly',
            animation_text: 'Aisyah & Faiz',
            accent_color: '#F59E0B',
            header_text_color: '#111827',
            card_background_color: '#FFFBEB'
          )
        end
      end

      # 2. Forbidden (Policy check: Member user)
      response '403', 'Forbidden (Member user)' do
        # FIX: Changed token from organizer_token to member_token
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

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT or Raw API Key'

      # 1. Success
      response '204', 'Deletion successful' do
        let(:Authorization) { "Bearer #{organizer_token}" }
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

  # --- DELETE - Force Delete ---
  path '/v1/events/{id}/force_delete' do
    parameter name: :id, in: :path, type: :integer, description: 'Event ID'

    delete 'Force deletes the event (hard delete)' do
      tags 'Events'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT or Raw API Key'

      # 1. Success
      response '204', 'Force deletion successful' do
        let(:Authorization) { "Bearer #{organizer_token}" }
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

  # --- PATCH - Restore ---
  path '/v1/events/{id}/restore' do
    parameter name: :id, in: :path, type: :integer, description: 'Event ID'

    patch 'Restores an archived event' do
      tags 'Events'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT or Raw API Key'

      # 1. Success
      response '200', 'Event successfully restored' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { event_paid.id }

        before do
          event_paid.archive
        end

        schema EVENT_SCHEMA
        run_test!
      end

      # 2. Forbidden (Member user)
      response '403', 'Forbidden (Member user)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { event_paid.id }
        run_test!
      end

      # 3. Not Found (already active event)
      response '404', 'Event not found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { 99_999 }
        run_test!
      end
    end
  end

  # =========================================================================
  # GET /v1/events/{id}/business_matching_events
  # =========================================================================

  path '/v1/events/{id}/business_matching_events' do
    parameter name: :id, in: :path, type: :integer, description: 'Event ID'

    get 'Retrieves business matching events for a specific event' do
      tags 'Events'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT or Raw API Key'

      let(:bm_events_response_data) do
        [
          { id: 1, title: 'Match Session 1', duration: 30, location: 'Virtual Link', admin_email: 'a1@example.com',
            admin_wa_number: '111' },
          { id: 2, title: 'Match Session 2', duration: 60, location: 'Physical Room', admin_email: 'a2@example.com',
            admin_wa_number: '222' }
        ]
      end

      before do
        allow_any_instance_of(BusinessMatchingService).to receive(:fetch_events).and_return(
          BusinessMatchingService::ServiceResult.new(success: true, data: bm_events_response_data)
        )
      end

      # 1. Success
      response '200', 'Business matching events found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { event_paid.id }

        before do
          event_paid.update!(use_business_matching: true)
        end

        schema BUSINESS_MATCHING_EVENT_SCHEMA
        run_test!
      end

      # 2. Forbidden (Member user - Pundit policy)
      response '403', 'Forbidden (Member user)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { event_paid.id }

        before do
          event_paid.update!(use_business_matching: true)
        end
        run_test!
      end

      # 3. Bad Request (Business matching not enabled for event)
      response '400', 'Business matching not enabled for this event' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { event_paid.id }

        before do
          event_paid.update!(use_business_matching: false) # Ensure it's false
        end
        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['errors']).to eq('Business matching is not enabled for this event')
        end
      end

      # 4. Service Error
      response '500', 'Service error' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:id) { event_paid.id }

        before do
          event_paid.update!(use_business_matching: true)
          allow_any_instance_of(BusinessMatchingService).to receive(:fetch_events).and_return(
            BusinessMatchingService::ServiceResult.new(success: false, errors: 'Webhook failed', status: 500)
          )
        end
        run_test! do |response|
          json = JSON.parse(response.body)
          expect(json['errors']).to eq('Webhook failed')
        end
      end
    end
  end

  # =========================================================================
  # Email Verification Requirement Tests
  # =========================================================================

  describe 'Email Verification Enforcement' do
    let(:unverified_user) { create(:user, :unverified) }
    let(:unverified_token) { JwtService.generate_tokens(unverified_user)[:access_token] }

    context 'when unverified user tries to access events' do
      it 'returns 403 Forbidden for index' do
        get '/v1/events', headers: { 'Authorization' => "Bearer #{unverified_token}" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['success']).to be false
        expect(json['message']).to eq('Email verification required')
      end

      it 'returns 403 Forbidden for show' do
        event = create(:event)
        get "/v1/events/#{event.id}", headers: { 'Authorization' => "Bearer #{unverified_token}" }

        expect(response).to have_http_status(:forbidden)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Email verification required')
      end
    end

    context 'when API key is used' do
      let!(:organizer_user) { create(:user, :organizer) }
      let!(:api_key) { ApiKey.create_key_for_user(organizer_user) }

      it 'bypasses email verification for API key authentication' do
        event = create(:event)
        create(:event_assignment, role: :event_admin, event: event, user: organizer_user)

        get "/v1/events/#{event.id}", headers: { 'Authorization' => api_key }

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'wish wall style settings API' do
    let(:event) do
      create(:event, payment_status: :paid, published: false, visibility: true).tap do |record|
        create(:event_assignment, role: :event_admin, event: record, user: organizer_user)
      end
    end

    it 'saves wish wall style colors in the response payload' do
      put "/v1/events/#{event.id}",
          params: {
            event: {
              wish_wall_setting_attributes: {
                display_mode: 'animation',
                animation_shape: 'heart',
                animation_text: 'Styled Wall',
                accent_color: '#F59E0B',
                header_text_color: '#111827',
                card_background_color: '#FFFBEB'
              }
            }
          },
          headers: auth_headers(organizer_user),
          as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig('wish_wall_setting', 'display_mode')).to eq('animation')
      expect(json.dig('wish_wall_setting', 'animation_shape')).to eq('heart')
      expect(json.dig('wish_wall_setting', 'animation_text')).to eq('Styled Wall')
      expect(json.dig('wish_wall_setting', 'accent_color')).to eq('#F59E0B')
      expect(json.dig('wish_wall_setting', 'header_text_color')).to eq('#111827')
      expect(json.dig('wish_wall_setting', 'card_background_color')).to eq('#FFFBEB')
      expect(json.dig('wish_wall_setting', 'background_image_url')).to be_nil

      expect(event.reload.wish_wall_setting).to have_attributes(
        display_mode: 'animation',
        animation_shape: 'heart',
        animation_text: 'Styled Wall',
        accent_color: '#F59E0B',
        header_text_color: '#111827',
        card_background_color: '#FFFBEB'
      )
    end

    it 'updates an existing wish wall setting record' do
      create(
        :wish_wall_setting,
        event: event,
        display_mode: 'animation',
        animation_shape: 'heart',
        accent_color: '#D4A373'
      )

      put "/v1/events/#{event.id}",
          params: {
            event: {
              wish_wall_setting_attributes: {
                display_mode: 'cards',
                animation_shape: '',
                animation_text: '',
                accent_color: '#E8B7C8',
                header_text_color: '#C63D4F',
                card_background_color: '#E8B7C8'
              }
            }
          },
          headers: auth_headers(organizer_user),
          as: :json

      expect(response).to have_http_status(:ok)
      expect(event.reload.wish_wall_setting).to have_attributes(
        display_mode: 'cards',
        animation_shape: nil,
        animation_text: nil,
        accent_color: '#E8B7C8',
        header_text_color: '#C63D4F',
        card_background_color: '#E8B7C8'
      )
    end

    it 'serializes the attached wish wall background image URL' do
      put "/v1/events/#{event.id}",
          params: {
            event: {
              wish_wall_background_image: fixture_file_upload(
                Rails.root.join('spec/fixtures/files/test_image.png'),
                'image/png'
              ),
              wish_wall_setting_attributes: {
                display_mode: 'cards'
              }
            }
          },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:ok)

      image_url = json.dig('wish_wall_setting', 'background_image_url')
      expect(image_url).to be_present
      expect(image_url).to include('/rails/active_storage/blobs/')
      expect(event.reload.wish_wall_setting.background_image).to be_attached
    end

    it 'rejects invalid wish wall background image uploads without persisting them' do
      put "/v1/events/#{event.id}",
          params: {
            event: {
              wish_wall_background_image: fixture_file_upload(
                Rails.root.join('spec/fixtures/files/test_image.png'),
                'application/pdf'
              ),
              wish_wall_setting_attributes: {
                display_mode: 'cards'
              }
            }
          },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:unprocessable_content)

      reloaded_setting = event.reload.wish_wall_setting
      expect(reloaded_setting.nil? || !reloaded_setting.background_image.attached?).to be(true)
    end

    it 'removes the attached wish wall background image' do
      setting = create(:wish_wall_setting, event: event)
      setting.background_image.attach(
        fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      )

      put "/v1/events/#{event.id}",
          params: {
            event: {
              remove_wish_wall_background_image: true,
              wish_wall_setting_attributes: {
                display_mode: setting.display_mode
              }
            }
          },
          headers: auth_headers(organizer_user),
          as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig('wish_wall_setting', 'background_image_url')).to be_nil
      expect(event.reload.wish_wall_setting.background_image).not_to be_attached
    end

    it 'keeps the attached wish wall background image when the update fails during removal' do
      setting = create(:wish_wall_setting, event: event)
      setting.background_image.attach(
        fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      )

      put "/v1/events/#{event.id}",
          params: {
            event: {
              title: nil,
              remove_wish_wall_background_image: true,
              wish_wall_setting_attributes: {
                display_mode: setting.display_mode
              }
            }
          },
          headers: auth_headers(organizer_user),
          as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(event.reload.wish_wall_setting.background_image).to be_attached
    end

    it 'does not attach the wish wall background image when the update fails' do
      put "/v1/events/#{event.id}",
          params: {
            event: {
              title: nil,
              wish_wall_background_image: fixture_file_upload(
                Rails.root.join('spec/fixtures/files/test_image.png'),
                'image/png'
              ),
              wish_wall_setting_attributes: {
                display_mode: 'cards'
              }
            }
          },
          headers: auth_headers(organizer_user)

      expect(response).to have_http_status(:unprocessable_content)

      reloaded_setting = event.reload.wish_wall_setting

      expect(reloaded_setting.nil? || !reloaded_setting.background_image.attached?).to be(true)
    end
  end
end
