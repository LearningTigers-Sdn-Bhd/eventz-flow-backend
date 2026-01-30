require 'swagger_helper'

RSpec.describe 'V1::SeatTicketing', type: :request do
  # --- Schemas ---
  let(:session_schema) do
    {
      type: :object,
      properties: {
        id: { type: :integer },
        event_id: { type: :integer },
        name: { type: :string },
        status: { type: :integer, example: 0 },
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
        row: { type: :integer },
        column: { type: :integer },
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
        prize: { type: :string, example: "50.0" },
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
    get 'List seat sessions' do
      tags 'Seat Ticketing'
      produces 'application/json'
      security [BearerAuth: []]
      parameter name: :event_id, in: :query, type: :integer, required: false
      parameter name: :archived, in: :query, type: :boolean, required: false
      parameter name: :full, in: :query, type: :boolean, required: false

      response '200', 'Success' do
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
        schema '$ref' => '#/components/schemas/EventSeatSession'
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{id}' do
    parameter name: :id, in: :path, type: :integer

    get 'Show seat session' do
      tags 'Seat Ticketing'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
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
        schema '$ref' => '#/components/schemas/EventSeatSession'
        run_test!
      end
    end

    delete 'Archive seat session' do
      tags 'Seat Ticketing'
      security [BearerAuth: []]

      response '204', 'Archived' do
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{id}/force_delete' do
    parameter name: :id, in: :path, type: :integer
    delete 'Force delete seat session' do
      tags 'Seat Ticketing'
      security [BearerAuth: []]
      response '204', 'Deleted' do
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{id}/restore' do
    parameter name: :id, in: :path, type: :integer
    patch 'Restore seat session' do
      tags 'Seat Ticketing'
      security [BearerAuth: []]
      response '200', 'Restored' do
        run_test!
      end
    end
  end

  # --- Venues ---
  path '/v1/seat_ticketing/sessions/{session_id}/venues' do
    parameter name: :session_id, in: :path, type: :integer

    get 'List venues' do
      tags 'Seat Ticketing - Venues'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
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
              row: { type: :integer },
              column: { type: :integer }
            },
            required: ['name']
          }
        }
      }

      response '201', 'Created' do
        schema '$ref' => '#/components/schemas/EventSeatVenue'
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{session_id}/venues/{id}' do
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show venue' do
      tags 'Seat Ticketing - Venues'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
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
              row: { type: :integer },
              column: { type: :integer }
            }
          }
        }
      }

      response '200', 'Success' do
        schema '$ref' => '#/components/schemas/EventSeatVenue'
        run_test!
      end
    end

    delete 'Delete venue' do
      tags 'Seat Ticketing - Venues'
      security [BearerAuth: []]

      response '204', 'Deleted' do
        run_test!
      end
    end
  end

  # --- Sections ---
  path '/v1/seat_ticketing/sessions/{session_id}/venues/{venue_id}/sections' do
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :venue_id, in: :path, type: :integer

    get 'List sections' do
      tags 'Seat Ticketing - Sections'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
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
              prize: { type: :string },
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
        schema '$ref' => '#/components/schemas/EventSeatSection'
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{session_id}/venues/{venue_id}/sections/{id}' do
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :venue_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show section' do
      tags 'Seat Ticketing - Sections'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
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
              prize: { type: :string },
              seat_row: { type: :integer },
              seat_column: { type: :integer },
              row_span: { type: :integer },
              col_span: { type: :integer }
            }
          }
        }
      }

      response '200', 'Success' do
        schema '$ref' => '#/components/schemas/EventSeatSection'
        run_test!
      end
    end

    delete 'Delete section' do
      tags 'Seat Ticketing - Sections'
      security [BearerAuth: []]

      response '204', 'Deleted' do
        run_test!
      end
    end
  end

  # --- Ticket Seats ---
  path '/v1/seat_ticketing/sessions/{session_id}/venues/{venue_id}/sections/{section_id}/ticket-seats' do
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :venue_id, in: :path, type: :integer
    parameter name: :section_id, in: :path, type: :integer

    get 'List ticket seats' do
      tags 'Seat Ticketing - Ticket Seats'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
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
        schema '$ref' => '#/components/schemas/EventTicketSeat'
        run_test!
      end
    end
  end

  path '/v1/seat_ticketing/sessions/{session_id}/venues/{venue_id}/sections/{section_id}/ticket-seats/{id}' do
    parameter name: :session_id, in: :path, type: :integer
    parameter name: :venue_id, in: :path, type: :integer
    parameter name: :section_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show ticket seat' do
      tags 'Seat Ticketing - Ticket Seats'
      produces 'application/json'
      security [BearerAuth: []]

      response '200', 'Success' do
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
        schema '$ref' => '#/components/schemas/EventTicketSeat'
        run_test!
      end
    end

    delete 'Delete ticket seat' do
      tags 'Seat Ticketing - Ticket Seats'
      security [BearerAuth: []]

      response '204', 'Deleted' do
        run_test!
      end
    end
  end

end
