# spec/requests/v1/event_locations_spec.rb
require 'swagger_helper'

# =========================================================================
# REUSABLE SCHEMAS (Defined as Global Constants for RSwag compatibility)
# =========================================================================

# The full EventLocation schema used for POST/GET/:id/PUT success responses.
EVENT_LOCATION_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer, example: 1 },
    event_id: { type: :integer, example: 1 },
    name: { type: :string, example: 'Main Hall' },
    scan_limit: { type: :integer, example: 100 },
    is_unlimited: { type: :boolean, default: false },
    floor: { type: :integer, example: 1, nullable: true },
    location_details: { 
      type: :object,
      additionalProperties: true,
      example: { wing: 'A', booth_number: '101' }
    },
    location_display_name: { type: :string, example: 'Main Hall - Floor 1 - Wing A' },
    created_at: { type: :string, format: :date_time },
    updated_at: { type: :string, format: :date_time },
    staff_members: {
      type: :array,
      items: {
        type: :object,
        properties: {
          id: { type: :integer },
          full_name: { type: :string },
          email: { type: :string },
          role: { type: :string },
          member_type: { type: :string, example: 'staff' }
        }
      }
    },
    vendors: {
      type: :array,
      items: {
        type: :object,
        properties: {
          id: { type: :integer },
          full_name: { type: :string },
          email: { type: :string },
          role: { type: :string },
          member_type: { type: :string, example: 'vendor' }
        }
      }
    }
  },
  required: ['id', 'event_id', 'name']
}.freeze

RSpec.describe 'V1::EventLocations', type: :request do
  # --- Setup Users ---
  let(:org_owner_user) { create(:org_owner) }
  let(:organizer_user) { create(:organizer_user) }
  let(:member_user) { create(:member_user) }
  let(:vendor_user) { create(:vendor_user) }

  # --- Setup Tokens ---
  let(:org_owner_token) { JwtService.generate_tokens(org_owner_user)[:access_token] }
  let(:organizer_token) { JwtService.generate_tokens(organizer_user)[:access_token] }
  let(:member_token) { JwtService.generate_tokens(member_user)[:access_token] }

  # --- Setup API Keys ---
  let!(:organizer_api_key) { ApiKey.create_key_for_user(organizer_user) }
  let!(:org_owner_api_key) { ApiKey.create_key_for_user(org_owner_user) }

  # --- Setup Event ---
  let!(:event) do
    event = create(:event, title: "Test Event", payment_status: :paid, published: false)
    create(:event_assignment, role: :event_admin, event: event, user: organizer_user)
    event
  end

  # --- Setup Event Locations ---
  let!(:event_location_1) do
    create(:event_location, event: event, name: "Main Hall", scan_limit: 100)
  end

  let!(:event_location_2) do
    create(:event_location, event: event, name: "VIP Lounge", scan_limit: 50)
  end

  # --- Setup Event Location Data ---
  let(:valid_create_params) do
    {
      event_location: {
        name: 'New Location',
        scan_limit: 75
      }
    }
  end

  let(:valid_create_params_with_members) do
    {
      event_location: {
        name: 'New Location with Members',
        scan_limit: 80,
        member_ids: [member_user.id]
      }
    }
  end

  let(:valid_create_params_with_staff_and_vendors) do
    {
      event_location: {
        name: 'Location with Staff and Vendors',
        scan_limit: 100,
        floor: 2,
        location_details: { wing: 'A', booth_number: '101' },
        member_ids: [member_user.id, vendor_user.id]
      }
    }
  end

  let(:update_params) do
    {
      event_location: {
        name: 'Updated Location Name',
        scan_limit: 150
      }
    }
  end

  let(:invalid_params) do
    {
      event_location: {
        name: '', # Invalid: name cannot be blank
        scan_limit: -10 # Invalid: scan_limit must be >= 0
      }
    }
  end

  # =========================================================================
  # GET /v1/events/:event_id/event_locations (Index)
  # =========================================================================

  path '/v1/events/{event_id}/event_locations' do
    parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'

    # --- GET - Index ---
    get 'Lists all event locations for an event' do
      tags 'Event Locations'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Success (Organizer JWT)
      response '200', 'Event locations returned' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }

        schema type: :array, items: EVENT_LOCATION_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to be >= 2
          location_names = json.map { |loc| loc['name'] }
          expect(location_names).to include('Main Hall', 'VIP Lounge')
        end
      end

      # 2. Success (API Key)
      response '200', 'Event locations returned via API Key' do
        let(:Authorization) { organizer_api_key }
        let(:event_id) { event.id }

        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to be >= 2
          location_names = json.map { |loc| loc['name'] }
          expect(location_names).to include('Main Hall', 'VIP Lounge')
        end
      end

      # 3. Forbidden (Member without event access)
      response '403', 'Forbidden (Not authorized to view event)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        run_test!
      end

      # 4. Unauthorized (Missing Token)
      response '401', 'Unauthorized (Missing Token)' do
        let(:Authorization) { 'Bearer ' }
        let(:event_id) { event.id }
        run_test!
      end

      # 5. Not Found (Invalid Event ID)
      response '404', 'Event not found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { 99999 }
        run_test!
      end
    end

    # --- POST - Create ---
    post 'Creates a new event location' do
      tags 'Event Locations'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'
      parameter name: :event_location, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Main Stage' },
          scan_limit: { type: :integer, example: 200 },
          is_unlimited: { type: :boolean, default: false },
          floor: { type: :integer, example: 1, nullable: true },
          location_details: {
            type: :object,
            additionalProperties: true,
            example: { wing: 'A', booth_number: '101', zone: 'North' },
            description: 'Optional: Dynamic JSONB field for custom location details'
          },
          member_ids: {
            type: :array,
            items: { type: :integer },
            example: [1, 2, 3],
            description: 'Optional: Array of user IDs to assign as location members (staff or vendors)'
          }
        },
        required: ['name']
      }

      # 1. Success (Organizer JWT)
      response '201', 'Event location created successfully' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:event_location) { valid_create_params }

        schema EVENT_LOCATION_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['name']).to eq('New Location')
          expect(json['scan_limit']).to eq(75)
        end
      end

      # 2. Success with Members (Organizer JWT)
      response '201', 'Event location created with assigned members' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:event_location) { valid_create_params_with_members }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['name']).to eq('New Location with Members')
          expect(json['staff_members'].count).to eq(1)
          expect(json['staff_members'].first['id']).to eq(member_user.id)
          expect(json['staff_members'].first['member_type']).to eq('staff')
        end
      end

      # 2b. Success with Staff and Vendors separated
      response '201', 'Event location created with staff and vendors separated' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:event_location) { valid_create_params_with_staff_and_vendors }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Location with Staff and Vendors')
          expect(json['floor'].to_i).to eq(2)
          expect(json['location_details']['wing']).to eq('A')
          expect(json['location_details']['booth_number']).to eq('101')
          expect(json['location_display_name']).to include('Floor 2')
          expect(json['staff_members'].count).to eq(1)
          expect(json['vendors'].count).to eq(1)
          expect(json['staff_members'].first['id']).to eq(member_user.id)
          expect(json['vendors'].first['id']).to eq(vendor_user.id)
        end
      end

      # 3. Success (API Key)
      response '201', 'Event location created by API Key' do
        let(:Authorization) { org_owner_api_key }
        let(:event_id) { event.id }
        let(:event_location) { valid_create_params }
        run_test!
      end

      # 4. Validation Error
      response '422', 'Unprocessable Entity (Invalid params)' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:event_location) { invalid_params }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['errors']).to be_present
        end
      end

      # 5. Forbidden (Member JWT)
      response '403', 'Forbidden (Not authorized to create locations)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        let(:event_location) { valid_create_params }
        run_test!
      end

      # 6. Unique Constraint (Duplicate name for same event)
      response '422', 'Unprocessable Entity (Duplicate location name)' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:event_location) { { event_location: { name: 'Main Hall', scan_limit: 100 } } }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['errors']).to be_present
        end
      end
    end
  end

  # =========================================================================
  # GET /v1/events/:event_id/event_locations/:id (Show)
  # =========================================================================

  path '/v1/events/{event_id}/event_locations/{id}' do
    parameter name: :event_id, in: :path, type: :integer, description: 'Event ID'
    parameter name: :id, in: :path, type: :integer, description: 'Event Location ID'

    # --- GET - Show ---
    get 'Retrieves a specific event location' do
      tags 'Event Locations'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Success (JWT)
      response '200', 'Event location found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { event_location_1.id }

        schema EVENT_LOCATION_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Main Hall')
          expect(json['scan_limit']).to eq(100)
        end
      end

      # 2. Success (API Key)
      response '200', 'Event location found via API Key' do
        let(:Authorization) { organizer_api_key }
        let(:event_id) { event.id }
        let(:id) { event_location_1.id }
        run_test!
      end

      # 3. Not Found (Invalid Location ID)
      response '404', 'Event location not found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { 99999 }
        run_test!
      end

      # 4. Forbidden (Member without access)
      response '403', 'Forbidden (Not authorized to view event)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        let(:id) { event_location_1.id }
        run_test!
      end
    end

    # --- PUT - Update ---
    put 'Updates an event location' do
      tags 'Event Locations'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'
      parameter name: :event_location, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string, example: 'Updated Hall Name' },
          scan_limit: { type: :integer, example: 250 },
          is_unlimited: { type: :boolean, default: false },
          floor: { type: :integer, example: 2, nullable: true },
          location_details: {
            type: :object,
            additionalProperties: true,
            example: { wing: 'B', booth_number: '202' },
            description: 'Optional: Dynamic JSONB field for custom location details'
          },
          member_ids: {
            type: :array,
            items: { type: :integer },
            example: [1, 2, 3],
            description: 'Optional: Array of user IDs to assign as location members (staff or vendors)'
          }
        }
      }

      # 1. Success (Organizer JWT)
      response '200', 'Update successful' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { event_location_1.id }
        let(:event_location) { update_params }

        schema EVENT_LOCATION_SCHEMA

        run_test! do
          json = JSON.parse(response.body)
          expect(json['name']).to eq('Updated Location Name')
          expect(json['scan_limit']).to eq(150)
        end
      end

      # 2. Success (API Key)
      response '200', 'Update successful via API Key' do
        let(:Authorization) { org_owner_api_key }
        let(:event_id) { event.id }
        let(:id) { event_location_2.id }
        let(:event_location) { update_params }
        run_test!
      end

      # 3. Validation Error
      response '422', 'Unprocessable Entity (Invalid params)' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { event_location_1.id }
        let(:event_location) { invalid_params }

        run_test! do
          json = JSON.parse(response.body)
          expect(json['errors']).to be_present
        end
      end

      # 4. Forbidden (Member JWT)
      response '403', 'Forbidden (Not authorized to update)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        let(:id) { event_location_1.id }
        let(:event_location) { update_params }
        run_test!
      end

      # 5. Not Found (Invalid Location ID)
      response '404', 'Event location not found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { 99999 }
        let(:event_location) { update_params }
        run_test!
      end
    end

    # --- DELETE - Destroy ---
    delete 'Deletes an event location' do
      tags 'Event Locations'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT or Raw API Key'

      # 1. Success (Organizer JWT)
      response '204', 'Deletion successful' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { event_location_1.id }

        run_test! do
          expect(EventLocation.exists?(event_location_1.id)).to be_falsey
        end
      end

      # 2. Success (API Key)
      response '204', 'Deletion successful via API Key' do
        let(:Authorization) { org_owner_api_key }
        let(:event_id) { event.id }
        let(:id) { event_location_2.id }
        run_test!
      end

      # 3. Forbidden (Member JWT)
      response '403', 'Forbidden (Not authorized to delete)' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:event_id) { event.id }
        let(:id) { event_location_1.id }
        run_test!
      end

      # 4. Not Found (Invalid Location ID)
      response '404', 'Event location not found' do
        let(:Authorization) { "Bearer #{organizer_token}" }
        let(:event_id) { event.id }
        let(:id) { 99999 }
        run_test!
      end
    end
  end
end
