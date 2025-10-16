# spec/requests/v1/tickets_spec.rb
require 'swagger_helper'

RSpec.describe 'V1::Tickets', type: :request do
  # --- Setup Users & Tokens ---
  # NOTE: Assuming you have factories defined for these user types
  let(:manager_user) { create(:manager_user) }
  let(:member_user) { create(:member_user) }
  let(:staff_user) { create(:staff_user) } # User with EventTeamMember role

  # NOTE: Assuming you have a JsonWebToken.encode method
  let(:manager_token) { JsonWebToken.encode(user_id: manager_user.id) }
  let(:staff_token) { JsonWebToken.encode(user_id: staff_user.id) }
  let(:member_token) { JsonWebToken.encode(user_id: member_user.id) }

  # --- Setup Event (Controlled by Manager) ---
  let!(:manager_event) do
    # Event and its admin/team members are created here for authorization
    event = create(:event, title: 'Manager Event', payment_status: :paid)
    EventAdmin.find_or_create_by!(event: event, user: manager_user)
    create(:event_team_member, event: event, user: staff_user) # Staff is authorized to check-in
    event
  end

  # --- Setup Ticket Type (required for Tickets) ---
  # Ensures a ticket type exists for the event to satisfy the Ticket model validation
  let!(:general_ticket_type) { create(:ticket_type, event: manager_event, name: 'GA') }

  # --- Setup Ticket Records for Show/Check-in tests ---
  let!(:purchased_ticket) do
    create(:ticket, event: manager_event, ticket_type: general_ticket_type, status: :purchased, attendee_name: 'Purchased Attendee')
  end
  let!(:checked_in_ticket) do
    create(:ticket, event: manager_event, ticket_type: general_ticket_type, checked_in: true, check_in_at: Time.current, status: :scanned, attendee_name: 'Scanned Attendee')
  end

  # --- Valid parameters for POST request ---
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
        let(:Authorization) { "Bearer #{manager_token}" } # Managers can create tickets
        run_test! do
          json = JSON.parse(response.body)
          expect(json['attendee_name']).to eq('New Ticket Holder')
          expect(json['custom_fields_data']['t_shirt_size']).to eq('L')
          expect(Ticket.count).to eq(3) # Check that ticket was persisted (2 setup + 1 new)
        end
      end

      response '403', 'Forbidden for event staff (Team Member)' do
        # Assuming EventPolicy#create_ticket? is set to only allow Admins/Managers, not Staff.
        let(:Authorization) { "Bearer #{staff_token}" }
        run_test!
      end
      
      response '422', 'Validation failure' do
        let(:Authorization) { "Bearer #{manager_token}" }
        let(:ticket) { { ticket: { attendee_name: 'No Email' } } } # Missing required email/type_id
        run_test!
      end
    end
  end

  # =========================================================================
  # Routes for specific ticket actions: /v1/events/:event_id/tickets/:id
  # =========================================================================

  path '/v1/events/{event_id}/tickets/{id}' do
    parameter name: :event_id, in: :path, type: :integer
    # The controller uses public_id/UUID, so we define 'id' as a string
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

      response '404', 'Not found for non-existent ticket' do
        let(:Authorization) { "Bearer #{staff_token}" }
        let(:id) { '00000000-0000-0000-0000-000000000000' } # Invalid UUID
        run_test!
      end
      
      response '403', 'Forbidden for unauthorized member user' do
        let(:Authorization) { "Bearer #{member_token}" }
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
        # Use a fresh, purchased ticket to test the check-in
        let(:id) { purchased_ticket.public_id }
        let(:Authorization) { "Bearer #{staff_token}" } # Staff can perform check-in
        
        run_test! do
          # Reload the ticket instance to check database state after request
          purchased_ticket.reload 
          expect(purchased_ticket.checked_in).to be true
          expect(purchased_ticket.status).to eq('scanned')
        end
      end

      response '422', 'Already checked in' do
        # Use the ticket that was created as already checked in
        let(:id) { checked_in_ticket.public_id }
        let(:Authorization) { "Bearer #{staff_token}" }
        
        run_test! do
          json = JSON.parse(response.body)
          expect(json['error']).to include('already checked in')
        end
      end

      response '403', 'Forbidden by unauthorized member user' do
        let(:id) { purchased_ticket.public_id }
        let(:Authorization) { "Bearer #{member_token}" }
        run_test!
      end
    end
  end
end