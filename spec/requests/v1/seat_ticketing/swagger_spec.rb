require 'swagger_helper'

RSpec.describe 'V1::SeatTicketing', type: :request do
  # --- Setup Users & Tokens ---
  let(:event_admin_user) { create(:user) }
  let(:event_admin_token) { JwtService.generate_tokens(event_admin_user)[:access_token] }
  let(:Authorization) { "Bearer #{event_admin_token}" }

  # --- Setup Event & Assignments ---
  let!(:event) { create(:event, payment_status: :paid, use_ticket: false, use_seat_ticketing: true) }
  let!(:event_assignment) { create(:event_assignment, role: :event_admin, event: event, user: event_admin_user) }

  # --- Setup Seat Ticketing Data ---
  let!(:seat_session_record) { create(:event_seat_session, event: event, status: :published) }
  let!(:venue_record) { create(:event_seat_venue, event_seat_session: seat_session_record) }
  let!(:section_record) { create(:event_seat_section, event_seat_venue: venue_record) }
  let!(:ticket_seat_record) { create(:event_ticket_seat, event_seat_section: section_record) }

  # --- Payload Helpers ---
  let(:session_payload) do
    {
      session: {
        event_id: event.id,
        name: 'Seat Session A',
        status: 'draft',
        location: 'Main Hall',
        start_datetime: Time.current.iso8601,
        end_datetime: 1.hour.from_now.iso8601
      }
    }
  end

  let(:session_update_payload) do
    {
      session: {
        name: 'Updated Seat Session'
      }
    }
  end

  let(:venue_payload) do
    {
      venue: {
        name: 'Venue A',
        total_row: 10,
        total_column: 12
      }
    }
  end

  let(:venue_update_payload) do
    {
      venue: {
        name: 'Updated Venue'
      }
    }
  end

  let(:section_payload) do
    {
      section: {
        name: 'Section A',
        price: '50.0',
        start_row: 1,
        start_column: 1,
        seat_row: 1,
        seat_column: 1,
        row_span: 1,
        col_span: 1
      }
    }
  end

  let(:section_update_payload) do
    {
      section: {
        name: 'Updated Section'
      }
    }
  end

  let(:ticket_seat_payload) do
    {
      ticket_seat: {
        name: 'A1',
        extra_price: '0.0',
        row_set: 1,
        col_set: 1
      }
    }
  end

  let(:ticket_seat_update_payload) do
    {
      ticket_seat: {
        name: 'A1-Updated'
      }
    }
  end

  # --- Schemas ---
  let(:session_schema) do
    {
      type: :object,
      properties: {
        id: { type: :integer },
        event_id: { type: :integer },
        name: { type: :string },
        status: { type: :string, example: 'draft' },
        location: { type: :string },
        start_datetime: { type: :string, format: :date_time },
        end_datetime: { type: :string, format: :date_time },
        deleted_at: { type: :string, format: :date_time, nullable: true },
        archived: { type: :boolean, nullable: true }
      }
    }
  end

  let(:venue_schema) do
    {
      type: :object,
      properties: {
        id: { type: :integer },
        name: { type: :string },
        total_row: { type: :integer },
        total_column: { type: :integer },
        image_url: { type: :string, nullable: true }
      }
    }
  end

  let(:section_schema) do
    {
      type: :object,
      properties: {
        id: { type: :integer },
        name: { type: :string },
        price: { type: :string, example: "50.0" },
        start_row: { type: :integer },
        start_column: { type: :integer },
        seat_row: { type: :integer },
        seat_column: { type: :integer },
        row_span: { type: :integer },
        col_span: { type: :integer }
      }
    }
  end

  let(:ticket_seat_schema) do
    {
      type: :object,
      properties: {
        id: { type: :integer },
        name: { type: :string },
        extra_price: { type: :string, example: "0.0" },
        row_set: { type: :integer },
        col_set: { type: :integer }
      }
    }
  end

  # --- Sessions ---
  path '/v1/seat_ticketing/sessions' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    get 'List seat sessions' do
      tags 'Seat Ticketing'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :event_id, in: :query, type: :integer, required: false
      parameter name: :archived, in: :query, type: :boolean, required: false
      parameter name: :full, in: :query, type: :boolean, required: false

      response '200', 'Success' do
        let(:event_id) { event.id }
        schema type: :array, items: { '$ref' => '#/components/schemas/EventSeatSession' }
        run_test!
      end
    end

    post 'Create seat session' do
      tags 'Seat Ticketing'
      consumes 'application/json'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :session, in: :body, schema: {
        type: :object,
        properties: {
          session: {
            type: :object,
            properties: {
              event_id: { type: :integer },
              name: { type: :string },
              status: { type: :integer, example: 0 },
              location: { type: :string },
              start_datetime: { type: :string, format: :date_time },
              end_datetime: { type: :string, format: :date_time }
            },
            required: ['event_id', 'name', 'start_datetime', 'end_datetime']
          }
        }
      }

      response '201', 'Created' do
        let(:session) { session_payload }
        schema '$ref' => '#/components/schemas/EventSeatSession'
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{id}' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :id, in: :path, type: :integer

    get 'Show seat session' do
      tags 'Seat Ticketing'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
        let(:id) { seat_session_record.id }
        schema '$ref' => '#/components/schemas/EventSeatSession'
        run_test!
      end
    end

    put 'Update seat session' do
      tags 'Seat Ticketing'
      consumes 'application/json'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :session, in: :body, schema: {
        type: :object,
        properties: {
          session: {
            type: :object,
            properties: {
              name: { type: :string },
              status: { type: :integer, example: 0 },
              location: { type: :string },
              start_datetime: { type: :string, format: :date_time },
              end_datetime: { type: :string, format: :date_time }
            }
          }
        }
      }

      response '200', 'Success' do
        let(:id) { seat_session_record.id }
        let(:session) { session_update_payload }
        schema '$ref' => '#/components/schemas/EventSeatSession'
        run_test!
      end
    end

    delete 'Archive seat session' do
      tags 'Seat Ticketing'
      security [BearerAuth: []]

      response '204', 'Archived' do
        let(:id) { seat_session_record.id }
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{id}/force_delete' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :id, in: :path, type: :integer
    delete 'Force delete seat session' do
      tags 'Seat Ticketing'
      security [BearerAuth: []]
      response '204', 'Deleted' do
        let(:id) { seat_session_record.id }
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{id}/restore' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :id, in: :path, type: :integer
    patch 'Restore seat session' do
      tags 'Seat Ticketing'
      security [BearerAuth: []]
      response '200', 'Restored' do
        let(:id) { seat_session_record.id }
        run_test!
      end
    end
  end

  # --- Venues ---
  path '/v1/seat_ticketing/sessions/{session_id}/venues' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :session_id, in: :path, type: :integer

    get 'List venues' do
      tags 'Seat Ticketing - Venues'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        schema type: :array, items: { '$ref' => '#/components/schemas/EventSeatVenue' }
        run_test!
      end
    end

    post 'Create venue' do
      tags 'Seat Ticketing - Venues'
      consumes 'application/json'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :venue, in: :body, schema: {
        type: :object,
        properties: {
          venue: {
            type: :object,
            properties: {
              name: { type: :string },
              total_row: { type: :integer },
              total_column: { type: :integer }
            },
            required: ['name']
          }
        }
      }

      response '201', 'Created' do
        let(:session_id) { seat_session_record.id }
        let(:venue) { venue_payload }
        schema '$ref' => '#/components/schemas/EventSeatVenue'
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{session_id}/venues/{id}' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show venue' do
      tags 'Seat Ticketing - Venues'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        let(:id) { venue_record.id }
        schema '$ref' => '#/components/schemas/EventSeatVenue'
        run_test!
      end
    end

    put 'Update venue' do
      tags 'Seat Ticketing - Venues'
      consumes 'application/json'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :venue, in: :body, schema: {
        type: :object,
        properties: {
          venue: {
            type: :object,
            properties: {
              name: { type: :string },
              total_row: { type: :integer },
              total_column: { type: :integer }
            }
          }
        }
      }

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        let(:id) { venue_record.id }
        let(:venue) { venue_update_payload }
        schema '$ref' => '#/components/schemas/EventSeatVenue'
        run_test!
      end
    end

    delete 'Delete venue' do
      tags 'Seat Ticketing - Venues'
      security [BearerAuth: []]

      response '204', 'Deleted' do
        let(:session_id) { seat_session_record.id }
        let(:id) { venue_record.id }
        run_test!
      end
    end
  end

  # --- Sections ---
  path '/v1/seat_ticketing/sessions/{session_id}/venues/{venue_id}/sections' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :venue_id, in: :path, type: :integer

    get 'List sections' do
      tags 'Seat Ticketing - Sections'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        schema type: :array, items: { '$ref' => '#/components/schemas/EventSeatSection' }
        run_test!
      end
    end

    post 'Create section' do
      tags 'Seat Ticketing - Sections'
      consumes 'application/json'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :section, in: :body, schema: {
        type: :object,
        properties: {
          section: {
            type: :object,
            properties: {
              name: { type: :string },
              price: { type: :string },
              start_row: { type: :integer },
              start_column: { type: :integer },
              seat_row: { type: :integer },
              seat_column: { type: :integer },
              row_span: { type: :integer },
              col_span: { type: :integer }
            },
            required: ['name']
          }
        }
      }

      response '201', 'Created' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:section) { section_payload }
        schema '$ref' => '#/components/schemas/EventSeatSection'
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{session_id}/venues/{venue_id}/sections/{id}' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :venue_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show section' do
      tags 'Seat Ticketing - Sections'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:id) { section_record.id }
        schema '$ref' => '#/components/schemas/EventSeatSection'
        run_test!
      end
    end

    put 'Update section' do
      tags 'Seat Ticketing - Sections'
      consumes 'application/json'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :section, in: :body, schema: {
        type: :object,
        properties: {
          section: {
            type: :object,
            properties: {
              name: { type: :string },
              price: { type: :string },
              start_row: { type: :integer },
              start_column: { type: :integer },
              seat_row: { type: :integer },
              seat_column: { type: :integer },
              row_span: { type: :integer },
              col_span: { type: :integer }
            }
          }
        }
      }

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:id) { section_record.id }
        let(:section) { section_update_payload }
        schema '$ref' => '#/components/schemas/EventSeatSection'
        run_test!
      end
    end

    delete 'Delete section' do
      tags 'Seat Ticketing - Sections'
      security [BearerAuth: []]

      response '204', 'Deleted' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:id) { section_record.id }
        run_test!
      end
    end
  end

  # --- Ticket Seats ---
  path '/v1/seat_ticketing/sessions/{session_id}/venues/{venue_id}/sections/{section_id}/ticket-seats' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :venue_id, in: :path, type: :integer
    parameter name: :section_id, in: :path, type: :integer

    get 'List ticket seats' do
      tags 'Seat Ticketing - Ticket Seats'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:section_id) { section_record.id }
        schema type: :array, items: { '$ref' => '#/components/schemas/EventTicketSeat' }
        run_test!
      end
    end

    post 'Create ticket seat' do
      tags 'Seat Ticketing - Ticket Seats'
      consumes 'application/json'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :ticket_seat, in: :body, schema: {
        type: :object,
        properties: {
          ticket_seat: {
            type: :object,
            properties: {
              name: { type: :string },
              extra_price: { type: :string },
              row_set: { type: :integer },
              col_set: { type: :integer },
              ticket_id: { type: :integer, nullable: true }
            },
            required: ['name']
          }
        }
      }

      response '201', 'Created' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:section_id) { section_record.id }
        let(:ticket_seat) { ticket_seat_payload }
        schema '$ref' => '#/components/schemas/EventTicketSeat'
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{session_id}/venues/{venue_id}/sections/{section_id}/ticket-seats/{id}' do
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer JWT'
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :venue_id, in: :path, type: :integer
    parameter name: :section_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show ticket seat' do
      tags 'Seat Ticketing - Ticket Seats'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:section_id) { section_record.id }
        let(:id) { ticket_seat_record.id }
        schema '$ref' => '#/components/schemas/EventTicketSeat'
        run_test!
      end
    end

    put 'Update ticket seat' do
      tags 'Seat Ticketing - Ticket Seats'
      consumes 'application/json'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :ticket_seat, in: :body, schema: {
        type: :object,
        properties: {
          ticket_seat: {
            type: :object,
            properties: {
              name: { type: :string },
              extra_price: { type: :string },
              row_set: { type: :integer },
              col_set: { type: :integer },
              ticket_id: { type: :integer, nullable: true }
            }
          }
        }
      }

      response '200', 'Success' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:section_id) { section_record.id }
        let(:id) { ticket_seat_record.id }
        let(:ticket_seat) { ticket_seat_update_payload }
        schema '$ref' => '#/components/schemas/EventTicketSeat'
        run_test!
      end
    end

    delete 'Delete ticket seat' do
      tags 'Seat Ticketing - Ticket Seats'
      security [BearerAuth: []]

      response '204', 'Deleted' do
        let(:session_id) { seat_session_record.id }
        let(:venue_id) { venue_record.id }
        let(:section_id) { section_record.id }
        let(:id) { ticket_seat_record.id }
        run_test!
      end
    end
  end

end
