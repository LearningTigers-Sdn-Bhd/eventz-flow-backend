require 'swagger_helper'

RSpec.describe 'V1::Tickets', type: :request do
  # --- Setup Users & Tokens ---
  let(:org_owner_user) { create(:org_owner) }
  let(:manager_user) { create(:manager_user) }
  let(:member_user) { create(:member_user) }
  let(:staff_user) { create(:staff_user) } # Assume a user with EventTeamMember role

  let(:org_owner_token) { JsonWebToken.encode(user_id: org_owner_user.id) }
  let(:manager_token) { JsonWebToken.encode(user_id: manager_user.id) }
  let(:staff_token) { JsonWebToken.encode(user_id: staff_user.id) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }

  # --- Setup Event (Controlled by Manager) ---
  let!(:manager_event) do
    event = create(:event, title: 'Manager Event', payment_status: :paid)
    EventAdmin.find_or_create_by!(event: event, user: manager_user)
    create(:event_team_member, event: event, user: staff_user)
    event
  end

  # --- Setup Ticket Type (required for Tickets) ---
  # The controller will create a default if needed, but we create one for testing stability.
  let!(:general_ticket_type) { create(:ticket_type, event: manager_event, name: 'GA') }

  # --- Setup Tickets ---
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
          expect(json.map { |t| t['attendee_name'] }).to include('Purchased Attendee', 'Scanned Attendee')
        end
        schema type: :array,
               items: {
                 type: :object,
                 properties: {
                   id: { type: :integer },
                   public_id: { type: :string, format: :uuid },
                   attendee_name: { type: :string },
                   status: { type: :string, enum: ['purchased', 'scanned', 'refunded', 'canceled'] }
                 }
               }
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
      
      parameter name: :ticket, in: :body, schema: {
        type: :object,
        properties: {
          ticket: {
            type: :object,
            properties: {
              attendee_name: { type: :string },
              attendee_email: { type: :string, format: :email },
              ticket_type_id: { type: :integer },
              custom_fields_data: { type: :object }
            },
            required: ['attendee_name', 'attendee_email']
          }
        },
        required: ['ticket']
      }

      let(:event_id) { manager_event.id }
      let(:ticket) { valid_ticket_params }

      response '201', 'Ticket created by Manager' do
        let(:Authorization) { "Bearer #{manager_token}" }
        run_test! do
          json = JSON.parse(response.body)
          expect(json['attendee_name']).to eq('New Ticket Holder')
          expect(json['custom_fields_data']['t_shirt_size']).to eq('L')
          expect(Ticket.count).to eq(3) # Check that ticket was persisted
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
    # Note: :id parameter is used for the ticket's public_id (UUID)
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
        run_test! do
          json = JSON.parse(response.body)
          expect(json['attendee_name']).to eq('Purchased Attendee')
        end
      end

      response '403', 'Not found by member user' do
        let(:Authorization) { "Bearer #{member_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' }
        run_test!
      end
    end
  end

  # =========================================================================
  # Custom Route: /v1/events/:event_id/tickets/:id/check_in
  # =========================================================================

  path '/v1/events/{event_id}/tickets/{id}/check_in' do
    parameter name: :event_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :string, description: 'Ticket Public ID (UUID)' 

    # --- PATCH - Check-in ---
    patch 'Marks a ticket as checked in' do
      tags 'Tickets'
      consumes 'application/json'
      produces 'application/json'
      security [{ BearerAuth: [] }]
      parameter name: :Authorization, in: :header, type: :string, required: true

      let(:event_id) { manager_event.id }
      
      response '200', 'Check-in successful by staff' do
        let(:id) { purchased_ticket.public_id }
        let(:Authorization) { "Bearer #{staff_token}" } # Staff can perform check-in (TicketPolicy#update?)
        run_test! do
          purchased_ticket.reload
          expect(purchased_ticket.checked_in).to be true
          expect(purchased_ticket.status).to eq('scanned')
        end
      end

      response '422', 'Already checked in' do
        let(:id) { checked_in_ticket.public_id }
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end

      response '403', 'Forbidden by unauthorized member user' do
        let(:id) { purchased_ticket.public_id }
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end
    end
  end
end