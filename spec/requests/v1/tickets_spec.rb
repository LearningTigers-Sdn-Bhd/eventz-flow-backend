# tickets_spec.rb
require 'swagger_helper'

# =========================================================================
# REUSABLE SCHEMAS (Defined as Global Constants for RSwag compatibility) 💡
# =========================================================================

# The full Ticket schema used for POST, GET/:id, PATCH, and PATCH check_in success responses.
TICKET_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer, readOnly: true, description: 'Internal database ID' },
    public_id: { type: :string, format: :uuid, description: 'The unique ID used for scanning/check-in.' },
    attendee_name: { type: :string },
    attendee_email: { type: :string, format: :email },
    attendee_phone: { type: [:string, :null] },
    status: { type: :string, enum: ['purchased', 'scanned', 'refunded', 'canceled'] },
    checked_in: { type: :boolean, readOnly: true },
    custom_fields_data: { type: :object, description: 'E.g., {"t_shirt_size": "L"}' },
    event_id: { type: :integer, readOnly: true },
    ticket_type_id: { type: :integer },
    ticket_type: { 
      type: :object,
      properties: {
        id: { type: :integer },
        name: { type: :string },
        price: { type: :string, description: 'Price as decimal string' }
      }
    }
  },
  required: ['public_id', 'attendee_name', 'attendee_email', 'status', 'event_id', 'ticket_type_id'],
  additionalProperties: true
}.freeze

# The minimal schema for the index array response (/v1/events/:event_id/tickets GET).
TICKET_INDEX_ITEM_SCHEMA = {
  type: :object,
  properties: {
    id: { type: :integer },
    public_id: { type: :string, format: :uuid },
    attendee_name: { type: :string },
    status: { type: :string, enum: ['purchased', 'scanned', 'refunded', 'canceled'] },
    ticket_type: { 
      type: :object,
      properties: {
        id: { type: :integer },
        name: { type: :string },
        price: { type: :string, description: 'Price as decimal string' }
      }
    }
  },
  additionalProperties: true
}.freeze


RSpec.describe 'V1::Tickets', type: :request do
  # --- Setup Users & Tokens (UNCHANGED) ---
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:member_user) { create(:member_user) }
  let(:staff_user) { create(:staff_user) } # Assume a user with EventTeamMember role

  let(:org_owner_token) { JsonWebToken.encode(user_id: org_owner_user.id) }
  let(:manager_token) { JsonWebToken.encode(user_id: manager_user.id) }
  let(:staff_token) { JsonWebToken.encode(user_id: staff_user.id) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }

  # --- Setup Event (Controlled by Manager) (UNCHANGED) ---
  let!(:manager_event) do
    event = create(:event, title: 'Manager Event', payment_status: :paid)
    EventAssignment.find_or_create_by!(event: event, user: manager_user, role: :event_admin)
    create(:event_assignment, role: :event_team_member, event: event, user: staff_user)
    event
  end

  # --- Setup Ticket Type (required for Tickets) (UNCHANGED) ---
  let!(:general_ticket_type) { create(:ticket_type, event: manager_event, name: 'GA') }

  # --- Setup Tickets (UNCHANGED) ---
  let!(:purchased_ticket) do
    create(:ticket, event: manager_event, ticket_type: general_ticket_type, status: :purchased, attendee_name: 'Purchased Attendee')
  end
  let!(:checked_in_ticket) do
    create(:ticket, event: manager_event, ticket_type: general_ticket_type, checked_in: true, check_in_at: Time.current, status: :scanned, attendee_name: 'Scanned Attendee')
  end
  let(:valid_ticket_params) do
    {
      ticket: {
        attendee_name: 'New Ticket Holder',
        attendee_email: 'new.holder@example.com',
        ticket_type_id: general_ticket_type.id,
        custom_fields_data: { t_shirt_size: 'L' }
      }
    }
  end

  # =========================================================================
  # Routes scoped under an event: /v1/events/:event_id/tickets
  # =========================================================================

  path '/v1/events/{event_id}/tickets' do
    parameter name: :event_id, in: :path, type: :integer, description: 'ID of the parent Event'
    
    # --- GET - Index ---
    get 'Lists all tickets for a specific event' do
      tags 'Tickets'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { manager_event.id }

      response '200', 'Returns list of tickets for authorized staff' do
        let(:Authorization) { "Bearer #{staff_token}" } # Staff can view tickets for their event
        run_test! do
          json = JSON.parse(response.body)
          expect(json.count).to eq(2)
        end
        
        # REFACTORED: Use reusable schema constant
        schema type: :array, items: TICKET_INDEX_ITEM_SCHEMA
      end

      response '403', 'Forbidden for unauthorized member user' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end
    end

    # --- POST - Create ---
    post 'Creates a new ticket (Staff Manual Entry)' do
      tags 'Tickets'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      
      # IMPROVED: Inline schema refined for documentation clarity
      parameter name: :ticket, in: :body, schema: {
        type: :object,
        properties: {
          ticket: {
            type: :object,
            properties: {
              attendee_name: { type: :string, example: 'John Doe' },
              attendee_email: { type: :string, format: :email, example: 'john.doe@example.com' },
              attendee_phone: { type: :string, example: '+1234567890' },
              ticket_type_id: { type: :integer, description: 'ID of the ticket type being purchased/issued' },
              custom_fields_data: { type: :object }
            },
            # IMPROVED: Added ticket_type_id to required fields for logic completeness
            required: ['attendee_name', 'attendee_email', 'ticket_type_id'] 
          }
        },
        required: ['ticket']
      }

      let(:event_id) { manager_event.id }
      let(:ticket) { valid_ticket_params }

      response '201', 'Ticket created by Manager' do
        let(:Authorization) { "Bearer #{manager_token}" }
        
        # REFACTORED: Use reusable schema constant
        schema TICKET_SCHEMA
        
        run_test! do
          expect(Ticket.count).to eq(3)
        end
      end

      response '403', 'Forbidden for event staff (Team Member)' do
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end
    end
  end

  # =========================================================================
  # Routes for specific ticket actions: /v1/events/:event_id/tickets/:id
  # =========================================================================

  path '/v1/events/{event_id}/tickets/{id}' do
    parameter name: :event_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :string, description: 'Ticket Public ID (UUID)'  

    # --- GET - Show ---
    get 'Retrieves a specific ticket' do
      tags 'Tickets'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { manager_event.id }
      let(:id) { purchased_ticket.public_id }

      response '200', 'Ticket found and viewable by staff' do
        let(:Authorization) { "Bearer #{staff_token}" }
        
        # REFACTORED: Use reusable schema constant
        schema TICKET_SCHEMA
        
        run_test!
      end

      response '403', 'Not found by member user' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' } 
        run_test!
      end
    end

    # ---------------------------------------------------------------------
    # --- PATCH - Update ---
    # ---------------------------------------------------------------------
    patch 'Updates a specific ticket' do
      tags 'Tickets'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true
      
      # IMPROVED: Inline request body schema
      parameter name: :ticket, in: :body, schema: {
        type: :object,
        properties: {
          ticket: {
            type: :object,
            properties: {
              attendee_name: { type: :string, example: 'Updated Name' },
              attendee_email: { type: :string, format: :email, example: 'new_email@example.com' },
              attendee_phone: { type: :string, example: '+1234567890' }
            }
          }
        }
      }

      let(:event_id) { manager_event.id }
      let(:id) { purchased_ticket.public_id } 
      let(:ticket) { { ticket: { attendee_name: 'Updated Name', attendee_email: 'update@example.com' } } }

      response '200', 'Ticket successfully updated by staff' do
        let(:Authorization) { "Bearer #{staff_token}" }
        
        # REFACTORED: Use reusable schema constant
        schema TICKET_SCHEMA
        
        run_test!
      end

      response '403', 'Forbidden for unauthorized user' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end
      
      response '404', 'Not Found' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end

    # ---------------------------------------------------------------------
    # --- DELETE - Destroy (Cancel/Refund) ---
    # ---------------------------------------------------------------------
    delete 'Cancels/Deletes a ticket (Soft Delete)' do
      tags 'Tickets'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { manager_event.id }
      let(:id) { checked_in_ticket.public_id } 

      response '204', 'Ticket successfully canceled by Manager' do
        let(:Authorization) { "Bearer #{manager_token}" }
        run_test!
      end

      response '403', 'Forbidden for event staff' do
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end
      
      response '404', 'Not Found' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end
  end

  # =========================================================================
  # Custom Route: /v1/tickets/:public_id/check_in
  # =========================================================================

  path '/v1/tickets/{public_id}/check_in' do
    parameter name: :public_id, in: :path, type: :string, description: 'Ticket Public ID (UUID)'  

    # --- PATCH - Global Check-in ---
    patch 'Performs a global check-in using only the Ticket Public ID' do
      tags 'Tickets'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:public_id) { purchased_ticket.public_id }
      
      response '200', 'Check-in successful via global scan by staff' do
        let(:Authorization) { "Bearer #{staff_token}" }
        
        # REFACTORED: Use reusable schema constant
        schema TICKET_SCHEMA
        
        run_test! do
          purchased_ticket.reload
          expect(purchased_ticket.checked_in).to be true
        end
      end

      response '422', 'Already checked in' do
        let(:public_id) { checked_in_ticket.public_id }
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end

      response '403', 'Forbidden for unauthorized user (member or staff of another event)' do
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end

      response '404', 'Not Found' do
        let(:public_id) { '00000000-0000-0000-0000-000000000000' }
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end
    end
  end
end
