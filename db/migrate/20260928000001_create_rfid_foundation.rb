# Plan 5 Task 1: the durable, event-scoped facts behind the RFID device API.
#
# Everything here is append-only history with snapshots, so a hard ticket
# delete or a revoked sticker never destroys the audit trail. Ticket and user
# foreign keys nullify instead of cascading; events own their RFID rows and
# cascade, because Event#delete already hard-deletes an event and its data.
class CreateRfidFoundation < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :rfid_mode, :string, null: false, default: 'bind'
    add_column :events, :rfid_require_check_in, :boolean, null: false, default: false

    add_column :scan_logs, :operation_id, :uuid
    add_index :scan_logs, :operation_id, unique: true, where: 'operation_id IS NOT NULL',
                                          name: 'idx_scan_logs_operation_id'

    create_table :rfid_stations do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.string :station_key, null: false
      t.string :name
      t.string :kind, null: false
      t.string :role
      t.string :uid_rule, null: false, default: 'as_is'
      t.string :hw_model
      t.string :firmware
      t.string :app_version
      t.datetime :last_heartbeat_at
      t.timestamps
    end
    add_index :rfid_stations, %i[event_id station_key], unique: true, name: 'idx_rfid_stations_event_key'

    create_table :rfid_bindings do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :ticket, foreign_key: { on_delete: :nullify }
      t.uuid :ticket_public_id, null: false
      t.string :ticket_name
      t.string :protocol, null: false
      t.string :uid_raw_hex, null: false
      t.string :tag_key, null: false
      t.string :mode, null: false
      t.integer :payload_version
      t.datetime :captured_at, null: false
      t.datetime :recorded_at, null: false
      t.datetime :revoked_at
      t.string :revocation_reason
      t.uuid :operation_id, null: false
      t.timestamps
    end
    # First committed binding wins: these two partial indexes are the
    # database's arbitration, not a validation, so two desks cannot both win.
    add_index :rfid_bindings, %i[event_id tag_key], unique: true,
                                                    where: 'revoked_at IS NULL',
                                                    name: 'idx_rfid_active_tag'
    add_index :rfid_bindings, %i[event_id ticket_id], unique: true,
                                                       where: 'revoked_at IS NULL',
                                                       name: 'idx_rfid_active_ticket'
    add_index :rfid_bindings, %i[event_id tag_key captured_at], name: 'idx_rfid_bindings_event_tag_capture'

    create_table :rfid_desk_operations do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :operation_id, null: false
      t.string :request_digest, null: false
      t.jsonb :original_response, null: false
      t.timestamps
    end
    add_index :rfid_desk_operations, %i[event_id operation_id], unique: true,
                                                                name: 'idx_rfid_desk_ops_event_op'

    create_table :rfid_binding_operations do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.uuid :operation_id, null: false
      t.string :request_digest, null: false
      t.jsonb :original_response, null: false
      t.timestamps
    end
    add_index :rfid_binding_operations, %i[event_id operation_id], unique: true,
                                                                   name: 'idx_rfid_binding_ops_event_op'

    create_table :rfid_observations do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :station, null: false, foreign_key: { to_table: :rfid_stations }
      t.references :ticket, foreign_key: { on_delete: :nullify }
      t.uuid :delivery_id, null: false
      t.bigint :device_record_seq
      t.string :role, null: false
      t.string :protocol, null: false
      t.string :uid_raw_hex, null: false
      t.string :tag_key, null: false
      t.string :payload_hex
      t.uuid :payload_public_id
      t.datetime :captured_at, null: false
      t.datetime :recorded_at, null: false
      t.jsonb :device_metadata, null: false, default: {}
      t.string :outcome, null: false
      t.jsonb :anomalies, null: false, default: []
      t.jsonb :original_response, null: false
      t.string :request_digest, null: false
      t.timestamps
    end
    add_index :rfid_observations, %i[station_id delivery_id], unique: true,
                                                              name: 'idx_rfid_obs_station_delivery'
    # Not unique: a duplicate delivery still needs its own stable saved reply.
    add_index :rfid_observations, %i[station_id device_record_seq], name: 'idx_rfid_obs_station_seq'
    add_index :rfid_observations, %i[event_id tag_key captured_at], name: 'idx_rfid_obs_event_tag_capture'
    add_index :rfid_observations, %i[event_id outcome], name: 'idx_rfid_obs_event_outcome'

    create_table :rfid_visits do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :ticket, foreign_key: { on_delete: :nullify }
      t.uuid :ticket_public_id, null: false
      t.string :ticket_name
      t.references :entry_observation, null: false, foreign_key: { to_table: :rfid_observations }
      t.references :exit_observation, foreign_key: { to_table: :rfid_observations }
      t.datetime :entry_at, null: false
      t.datetime :exit_at
      t.boolean :manual, null: false, default: false
      t.jsonb :anomalies, null: false, default: []
      t.timestamps
    end
    add_index :rfid_visits, :entry_observation_id, unique: true, name: 'idx_rfid_visits_entry_observation'
    add_index :rfid_visits, %i[event_id ticket_id entry_at], name: 'idx_rfid_visits_event_ticket_entry'

    create_table :rfid_corrections do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :actor, foreign_key: { to_table: :users, on_delete: :nullify }
      t.references :entry_observation, null: false, foreign_key: { to_table: :rfid_observations }
      t.string :kind, null: false
      t.datetime :exit_at, null: false
      t.string :reason, null: false
      t.timestamps
    end
    add_index :rfid_corrections, %i[event_id entry_observation_id], name: 'idx_rfid_corrections_event_entry'
    add_index :rfid_corrections, %i[event_id actor_id], name: 'idx_rfid_corrections_event_actor'
  end
end
