require 'swagger_helper'

# Plan 5 Task 8: the RfiDex device API and the staff API, documented and
# executed. Each `run_test!` issues the real request, so the schema and the
# behaviour cannot drift apart. Nothing here is mounted outside local Rails.
RSpec.describe 'V1::Rfid API', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:event) { create(:event, use_api_access: true) }
  let(:key) { create(:api_key, user: owner, event: event, scope: 'rfid') }
  let(:Authorization) { key.raw_key }
  let(:'X-RfiDex-Station') { 'desk-contract' }
  let(:ticket_type) { create(:ticket_type, event: event, name: 'Delegate') }
  let(:ticket) do
    create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Ahmad Bin Ali',
                            attendee_email: 'Ahmad@Example.com', attendee_phone: '012-345 6789')
  end
  let(:captured_at) { '2026-09-26T09:14:03.000000Z' }
  let(:station) { create(:rfid_station, event: event, station_key: 'desk-contract', kind: 'desk') }
  let(:tag) { '3412CDAB500104E0' }

  ERROR_SCHEMA = {
    type: :object,
    properties: {
      error: { type: :string, enum: %w[unauthorized ticket_not_found ticket_unpaid ticket_cancelled
                                       uid_bound_elsewhere ticket_has_sticker reason_required
                                       batch_too_large malformed] },
      message: { type: :string },
      holder: { type: :object, nullable: true },
      binding: { type: :object, nullable: true }
    },
    required: %w[error message holder binding]
  }.freeze

  TICKET_SUMMARY_SCHEMA = {
    type: :object,
    properties: {
      public_id: { type: :string, format: :uuid },
      name: { type: :string },
      ticket_type: { type: :string },
      valid: { type: :boolean },
      checked_in: { type: :boolean }
    },
    required: %w[public_id name ticket_type valid checked_in]
  }.freeze

  BINDING_INFO_SCHEMA = {
    type: :object,
    properties: {
      id: { type: :integer },
      public_id: { type: :string, format: :uuid },
      protocol: { type: :string, enum: %w[iso15693 iso14443a iso18000_6c unknown] },
      uid_raw_hex: { type: :string },
      tag_key: { type: :string },
      mode: { type: :string, enum: %w[bind written] }
    },
    required: %w[id public_id protocol uid_raw_hex tag_key mode]
  }.freeze

  path '/v1/rfid/stations/heartbeat' do
    post 'Registers a station and returns the event settings' do
      tags 'RfiDex device'
      consumes 'application/json'
      produces 'application/json'
      security [{ apiKeyAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Event-scoped rfid API key'
      parameter name: :'X-RfiDex-Station', in: :header, type: :string, required: true,
                description: 'Opaque station id, 1-128 printable ASCII characters'
      parameter name: :heartbeat, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string }, kind: { type: :string, enum: %w[desk gate] },
          role: { type: :string, enum: %w[entry exit], nullable: true },
          hw_model: { type: :string, nullable: true }, firmware: { type: :string, nullable: true },
          app_version: { type: :string }
        },
        required: %w[name kind app_version]
      }

      response '200', 'station registered' do
        let(:heartbeat) do
          { name: 'Registration desk', kind: 'desk', role: nil, app_version: '0.3.0' }
        end

        schema type: :object, properties: {
          event: {
            type: :object,
            properties: {
              event_id: { type: :integer }, name: { type: :string },
              rfid_mode: { type: :string, enum: %w[bind write] },
              require_check_in: { type: :boolean }
            },
            required: %w[event_id name rfid_mode require_check_in]
          },
          uid_rule: { type: :string, enum: %w[as_is reversed] },
          server_time: { type: :string, format: :date_time }
        }, required: %w[event uid_rule server_time]

        run_test!
      end

      response '409', 'the station tried to change its configured role' do
        before { create(:rfid_station, event: event, station_key: 'desk-contract', kind: 'gate', role: 'entry') }

        let(:heartbeat) { { name: 'Gate', kind: 'gate', role: 'exit', app_version: '0.3.0' } }
        schema ERROR_SCHEMA

        run_test!
      end
    end
  end

  path '/v1/rfid/cache' do
    get 'Full offline snapshot: tickets, active bindings, revoked keys' do
      tags 'RfiDex device'
      produces 'application/json'
      security [{ apiKeyAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'X-RfiDex-Station', in: :header, type: :string, required: true
      parameter name: :since, in: :query, type: :string, required: false,
                description: 'Accepted and ignored: the snapshot is always full'

      response '200', 'the snapshot' do
        before { ticket }

        schema type: :object, properties: {
          tickets: { type: :array, items: TICKET_SUMMARY_SCHEMA },
          bindings: { type: :array, items: BINDING_INFO_SCHEMA },
          revoked_tag_keys: { type: :array, items: { type: :string } },
          server_time: { type: :string, format: :date_time }
        }, required: %w[tickets bindings revoked_tag_keys server_time]

        run_test!
      end
    end
  end

  path '/v1/rfid/tickets/search' do
    get 'Desk search by name, email or phone (masked)' do
      tags 'RfiDex device'
      produces 'application/json'
      security [{ apiKeyAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'X-RfiDex-Station', in: :header, type: :string, required: true
      parameter name: :by, in: :query, type: :string, required: true,
                enum: %w[name email phone]
      parameter name: :q, in: :query, type: :string, required: true

      response '200', 'matches, newest first, at most ten' do
        before { ticket }

        let(:by) { 'name' }
        let(:q) { 'ahmad' }

        schema type: :object, properties: {
          tickets: {
            type: :array,
            items: {
              type: :object,
              properties: {
                public_id: { type: :string, format: :uuid }, name: { type: :string },
                ticket_type: { type: :string }, valid: { type: :boolean },
                checked_in: { type: :boolean },
                checked_in_at: { type: :string, format: :date_time, nullable: true },
                email_hint: { type: :string, nullable: true },
                phone_hint: { type: :string, nullable: true }
              },
              required: %w[public_id name ticket_type valid checked_in]
            }
          }
        }, required: %w[tickets]

        run_test!
      end

      response '400', 'unknown search field' do
        let(:by) { 'staff' }
        let(:q) { 'ahmad' }
        schema ERROR_SCHEMA

        run_test!
      end
    end
  end

  path '/v1/rfid/desk_scans' do
    post 'Checks a guest in, idempotently per operation id' do
      tags 'RfiDex device'
      consumes 'application/json'
      produces 'application/json'
      security [{ apiKeyAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'X-RfiDex-Station', in: :header, type: :string, required: true
      parameter name: :desk_scan, in: :body, schema: {
        type: :object,
        properties: {
          public_id: { type: :string, format: :uuid },
          operation_id: { type: :string, format: :uuid },
          captured_at: { type: :string, format: :date_time }
        },
        required: %w[public_id operation_id captured_at]
      }

      response '200', 'the check-in, or the replay of the first one' do
        let(:desk_scan) do
          { public_id: ticket.public_id, operation_id: SecureRandom.uuid, captured_at: captured_at }
        end

        schema type: :object, properties: {
          ticket: TICKET_SUMMARY_SCHEMA,
          binding: BINDING_INFO_SCHEMA.merge(nullable: true),
          check_in: {
            type: :object,
            properties: {
              result: { type: :string, enum: %w[checked_in already_checked_in] },
              checked_in_at: { type: :string, format: :date_time }
            },
            required: %w[result checked_in_at]
          }
        }, required: %w[ticket binding check_in]

        run_test!
      end

      response '422', 'the ticket cannot be checked in' do
        let(:unpaid) do
          create(:ticket, event: event, ticket_type: ticket_type, attendee_name: 'Unpaid Guest')
        end
        let(:desk_scan) do
          { public_id: unpaid.public_id, operation_id: SecureRandom.uuid, captured_at: captured_at }
        end

        schema ERROR_SCHEMA

        run_test!
      end
    end
  end

  path '/v1/rfid/bindings' do
    post 'Links a sticker to a ticket' do
      tags 'RfiDex device'
      consumes 'application/json'
      produces 'application/json'
      security [{ apiKeyAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'X-RfiDex-Station', in: :header, type: :string, required: true
      parameter name: :binding, in: :body, schema: {
        type: :object,
        properties: {
          public_id: { type: :string, format: :uuid },
          protocol: { type: :string, enum: %w[iso15693 iso14443a iso18000_6c unknown] },
          uid_raw_hex: { type: :string },
          mode: { type: :string, enum: %w[bind written] },
          payload_version: { type: :integer, nullable: true },
          operation_id: { type: :string, format: :uuid },
          captured_at: { type: :string, format: :date_time },
          replace: { type: :boolean },
          reason: { type: :string, nullable: true }
        },
        required: %w[public_id protocol uid_raw_hex mode operation_id captured_at]
      }

      response '201', 'the sticker is linked' do
        let(:binding) do
          { public_id: ticket.public_id, protocol: 'iso15693', uid_raw_hex: tag, mode: 'bind',
            payload_version: nil, operation_id: SecureRandom.uuid, captured_at: captured_at,
            replace: false, reason: nil }
        end

        schema type: :object, properties: {
          binding: BINDING_INFO_SCHEMA,
          revoked: { type: :array, items: BINDING_INFO_SCHEMA }
        }, required: %w[binding revoked]

        run_test!
      end

      response '409', 'the sticker is already on another ticket' do
        before do
          Rfid::Binding.create!(event: event, ticket: ticket, ticket_public_id: ticket.public_id,
                                ticket_name: ticket.attendee_name, protocol: 'iso15693',
                                uid_raw_hex: tag, tag_key: tag, mode: 'bind',
                                captured_at: Time.current, operation_id: SecureRandom.uuid)
        end
        let(:other) do
          create(:ticket, :paid, event: event, ticket_type: ticket_type, attendee_name: 'Other Guest')
        end
        let(:binding) do
          { public_id: other.public_id, protocol: 'iso15693', uid_raw_hex: tag, mode: 'bind',
            payload_version: nil, operation_id: SecureRandom.uuid, captured_at: captured_at,
            replace: false, reason: nil }
        end

        schema ERROR_SCHEMA

        run_test!
      end
    end
  end

  path '/v1/rfid/bindings/lookup' do
    get 'Who holds this sticker right now' do
      tags 'RfiDex device'
      produces 'application/json'
      security [{ apiKeyAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'X-RfiDex-Station', in: :header, type: :string, required: true
      parameter name: :uid_raw_hex, in: :query, type: :string, required: true
      parameter name: :protocol, in: :query, type: :string, required: false,
                enum: %w[iso15693 iso14443a iso18000_6c unknown]

      response '200', 'the active binding and holder, or two nulls' do
        let(:uid_raw_hex) { tag }

        schema type: :object, properties: {
          binding: BINDING_INFO_SCHEMA.merge(nullable: true),
          holder: TICKET_SUMMARY_SCHEMA.merge(nullable: true)
        }, required: %w[binding holder]

        run_test!
      end
    end
  end

  path '/v1/rfid/observations' do
    post 'Records a batch of gate readings' do
      tags 'RfiDex device'
      consumes 'application/json'
      produces 'application/json'
      security [{ apiKeyAuth: [] }]

      # The station row is part of the evidence each reading cites.
      before { station }

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :'X-RfiDex-Station', in: :header, type: :string, required: true
      parameter name: :observations, in: :body, schema: {
        type: :object,
        properties: {
          observations: {
            type: :array,
            maxItems: 50,
            items: {
              type: :object,
              properties: {
                delivery_id: { type: :string, format: :uuid },
                role: { type: :string, enum: %w[entry exit] },
                protocol: { type: :string, enum: %w[iso15693 iso14443a iso18000_6c unknown] },
                uid_raw_hex: { type: :string },
                payload_hex: { type: :string, nullable: true },
                device_direction_raw: { type: :integer, nullable: true },
                device_time_raw_hex: { type: :string, nullable: true },
                device_record_seq: { type: :integer, nullable: true },
                flags_raw: { type: :object, nullable: true },
                captured_at: { type: :string, format: :date_time }
              },
              required: %w[delivery_id role protocol uid_raw_hex captured_at]
            }
          }
        },
        required: %w[observations]
      }

      response '200', 'one result per reading, in order' do
        let(:observations) do
          { observations: [{ delivery_id: SecureRandom.uuid, role: 'entry', protocol: 'iso15693',
                             uid_raw_hex: tag, payload_hex: nil, device_direction_raw: nil,
                             device_time_raw_hex: nil, device_record_seq: nil, flags_raw: {},
                             captured_at: captured_at }] }
        end

        schema type: :object, properties: {
          results: {
            type: :array,
            items: {
              type: :object,
              properties: {
                delivery_id: { type: :string, format: :uuid },
                outcome: { type: :string, enum: %w[accepted unknown_tag revoked_tag wrong_event
                                                   ticket_invalid not_checked_in
                                                   possible_duplicate] },
                anomalies: { type: :array, items: { type: :string } },
                display: {
                  type: :object,
                  properties: {
                    name: { type: :string, nullable: true },
                    ticket_type: { type: :string, nullable: true },
                    reason: { type: :string, nullable: true }
                  }
                }
              },
              required: %w[delivery_id outcome display]
            }
          }
        }, required: %w[results]

        run_test!
      end

      response '422', 'more than fifty readings' do
        let(:observations) do
          { observations: Array.new(51) do
            { delivery_id: SecureRandom.uuid, role: 'entry', protocol: 'iso15693',
              uid_raw_hex: tag, payload_hex: nil, device_direction_raw: nil,
              device_time_raw_hex: nil, device_record_seq: nil, flags_raw: {},
              captured_at: captured_at }
          end }
        end

        schema ERROR_SCHEMA

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/rfid/summary' do
    get 'Live RFID summary for event staff' do
      tags 'RfiDex staff'
      produces 'application/json'
      security [{ bearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true,
                description: 'Bearer JWT of event staff'
      parameter name: :event_id, in: :path, type: :integer, required: true

      let(:Authorization) { "Bearer #{JwtService.generate_tokens(owner)[:access_token]}" }
      let(:event_id) { event.id }

      response '200', 'the summary' do
        schema type: :object, properties: {
          headcount: { type: :integer }, open_visits: { type: :integer },
          anomaly_count: { type: :integer },
          last_observed_at: { type: :string, format: :date_time, nullable: true }
        }, required: %w[headcount open_visits anomaly_count last_observed_at]

        run_test!
      end

      response '403', 'an API key cannot manage RFID' do
        let(:Authorization) { key.raw_key }

        schema type: :object, properties: {
          success: { type: :boolean }, message: { type: :string },
          errors: { type: :array }
        }, required: %w[success message]

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/rfid/settings' do
    patch 'Changes the event RFID settings' do
      tags 'RfiDex staff'
      consumes 'application/json'
      produces 'application/json'
      security [{ bearerAuth: [] }]

      parameter name: :Authorization, in: :header, type: :string, required: true
      parameter name: :event_id, in: :path, type: :integer, required: true
      parameter name: :settings, in: :body, schema: {
        type: :object,
        properties: {
          rfid_mode: { type: :string, enum: %w[bind write] },
          require_check_in: { type: :boolean }
        }
      }

      let(:Authorization) { "Bearer #{JwtService.generate_tokens(owner)[:access_token]}" }
      let(:event_id) { event.id }

      response '200', 'the new settings' do
        let(:settings) { { rfid_mode: 'write', require_check_in: true } }

        schema type: :object, properties: {
          settings: {
            type: :object,
            properties: {
              event_id: { type: :integer }, rfid_mode: { type: :string },
              require_check_in: { type: :boolean }
            },
            required: %w[event_id rfid_mode require_check_in]
          }
        }, required: %w[settings]

        run_test!
      end
    end
  end
end
