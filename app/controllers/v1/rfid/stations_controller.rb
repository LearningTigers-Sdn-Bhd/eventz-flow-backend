module V1
  module Rfid
    # POST /v1/rfid/stations/heartbeat
    #
    # The heartbeat registers the station and hands back the event settings the
    # station needs to decide offline work. A later heartbeat may update the
    # status fields and the gate's role: RfiDex Setup owns the direction, and
    # staff switch gates between entry and exit during the day. Each reading
    # carries the role it was captured under, so history stays truthful.
    class StationsController < BaseController
      def heartbeat
        body = parsed_body
        name = string_field(body, 'name', max: 255)
        kind = enum_field(body, 'kind', ::Rfid::Station::KINDS)
        role = optional_enum_field(body, 'role', ::Rfid::Station::ROLES)
        hw_model = optional_string_field(body, 'hw_model', max: 255)
        firmware = optional_string_field(body, 'firmware', max: 255)
        app_version = string_field(body, 'app_version', max: 64)

        station = ::Rfid::Station.find_or_initialize_by(event: rfid_event,
                                                       station_key: station_key)
        station.assign_attributes(name: name, kind: kind, role: role, hw_model: hw_model,
                                  firmware: firmware, app_version: app_version,
                                  last_heartbeat_at: Time.current)
        station.save!

        render json: {
          event: {
            event_id: rfid_event.id,
            name: rfid_event.title,
            rfid_mode: rfid_event.rfid_mode,
            require_check_in: rfid_event.rfid_require_check_in
          },
          uid_rule: station.uid_rule,
          server_time: ::Rfid::Wire.time(Time.current)
        }, status: :ok
      end
    end
  end
end
