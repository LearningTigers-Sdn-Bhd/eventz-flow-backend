module V1
  # Staff-facing RFID API (P6 target). Every action needs a signed-in user:
  # the event-scoped `rfid` key, and any other API key, is refused here even
  # when the event's policy would otherwise allow the key's owner. Reads use
  # `EventPolicy#analytics?`, settings and corrections use `#update?`.
  class RfidManagementController < ApplicationController
    before_action :require_staff_session!
    before_action :set_event
    before_action :authorize_read!, only: %i[summary stations bindings visits visits_csv anomalies]
    before_action :authorize_update!, only: %i[update_settings update_station manual_exit]
    before_action :authorize_admin!, only: %i[destroy_station update_binding destroy_binding
                                              dismiss_anomalies destroy_anomalies]

    rescue_from ::Rfid::Admin::Error do |error|
      render json: { success: false, message: error.message, errors: [] }, status: error.status
    end

    def summary
      render json: report.summary, status: :ok
    end

    def stations
      render json: { stations: report.stations }, status: :ok
    end

    def bindings
      render json: { bindings: report.bindings }, status: :ok
    end

    def visits
      pagy, visits = pagy(report.visits_scope, limit: pagination_params[:per_page] || 25)

      render json: { visits: report.visit_rows(visits), pagination: pagy_metadata(pagy) },
             status: :ok
    end

    def visits_csv
      send_data report.visits_csv,
                filename: "rfid-visits-event-#{@event.id}.csv",
                type: 'text/csv; charset=utf-8',
                disposition: 'attachment'
    end

    def anomalies
      pagy, observations = pagy(report.anomaly_observations,
                                limit: pagination_params[:per_page] || 25)

      render json: {
        observations: observations.map { |row| report.anomaly_observation_row(row) },
        visits: report.visit_rows(report.anomaly_visits.limit(pagy.limit)),
        pagination: pagy_metadata(pagy)
      }, status: :ok
    end

    def update_settings
      attributes = {}

      if params.key?(:rfid_mode)
        mode = params[:rfid_mode].to_s
        unless Event::RFID_MODES.include?(mode)
          return unprocessable("rfid_mode must be one of #{Event::RFID_MODES.join(', ')}")
        end

        attributes[:rfid_mode] = mode
      end

      if params.key?(:require_check_in)
        value = params[:require_check_in]
        return unprocessable('require_check_in must be true or false') unless [true, false].include?(value)

        attributes[:rfid_require_check_in] = value
      end

      return unprocessable('rfid_mode or require_check_in is required') if attributes.empty?

      # Only the two RFID settings can move here: a general event update is a
      # different route with a different policy, and `write` changes the event
      # mode only — RfiDex still refuses physical writes until P4 acceptance.
      @event.update!(attributes)

      render json: { settings: settings_payload }, status: :ok
    end

    def update_station
      station = @event.rfid_stations.find_by(id: params[:id])
      return render json: { error: 'Station not found' }, status: :not_found if station.nil?

      reason = params[:reason].to_s.strip
      return unprocessable('A reason is required.') if reason.empty?
      unless ActiveModel::Type::Boolean.new.cast(params[:confirm])
        return unprocessable('This change must be confirmed explicitly.')
      end

      changes = {}
      if params.key?(:role)
        role = params[:role].present? ? params[:role].to_s : nil
        unless role.nil? || ::Rfid::Station::ROLES.include?(role)
          return unprocessable("role must be one of #{::Rfid::Station::ROLES.join(', ')}")
        end

        changes[:role] = role
      end
      if params.key?(:uid_rule)
        uid_rule = params[:uid_rule].to_s
        unless ::Rfid::Station::UID_RULES.include?(uid_rule)
          return unprocessable("uid_rule must be one of #{::Rfid::Station::UID_RULES.join(', ')}")
        end

        changes[:uid_rule] = uid_rule
      end
      return unprocessable('role or uid_rule is required') if changes.empty?

      observation_ids = Array(params[:observation_ids]).map(&:to_s).uniq
      unless observation_ids.all? { |id| id.match?(/\A\d+\z/) }
        return unprocessable('observation_ids must be a list of observation ids')
      end
      if observation_ids.any? &&
         station.event.rfid_observations.where(station_id: station.id, id: observation_ids).count != observation_ids.length
        return unprocessable('observation_ids must belong to this station')
      end

      @event.with_lock do
        station.update!(changes)
        ::Rfid::Correction.create!(
          event: @event, actor: current_user, station: station, kind: 'station_change',
          reason: reason,
          details: changes.merge('observation_ids' => observation_ids)
        )

        # Only the explicitly named readings are re-measured: a station change
        # applies to future reads, and past raw records are never rewritten.
        if observation_ids.any?
          ::Rfid::Visits.refresh_ids_locked!(event: @event, observation_ids: observation_ids)
          ::Rfid::Visits.rebuild!(event: @event)
        end
      end

      render json: { station: report.stations.find { |row| row[:id] == station.id } }, status: :ok
    end

    def manual_exit
      visit = @event.rfid_visits.find_by(id: params[:id])
      return render json: { error: 'Visit not found' }, status: :not_found if visit.nil?

      reason = params[:reason].to_s.strip
      return unprocessable('A reason is required.') if reason.empty?

      at = parse_time(params[:at])
      return unprocessable('at must be an RFC3339 timestamp') if at.nil?
      return unprocessable('The exit cannot be before the visit started.') if at < visit.entry_at
      return unprocessable('This visit is already closed.') unless visit.open?

      @event.with_lock do
        visit.reload
        return unprocessable('This visit is already closed.') unless visit.open?
        return unprocessable('The exit cannot be before the visit started.') if at < visit.entry_at

        ::Rfid::Correction.create!(
          event: @event, actor: current_user, entry_observation: visit.entry_observation,
          kind: 'manual_exit', exit_at: at, reason: reason,
          details: { 'entry_observation_id' => visit.entry_observation_id }
        )
        ::Rfid::Visits.rebuild!(event: @event)
      end

      render json: { visit: report.visit_row(visit.reload) }, status: :ok
    end

    # --- Org-owner clean-up (see ::Rfid::Admin) ---------------------------------

    def destroy_station
      station = @event.rfid_stations.find_by(id: params[:id])
      return render json: { error: 'Station not found' }, status: :not_found if station.nil?

      admin.delete_station!(station)
      render json: { deleted: true }, status: :ok
    end

    def update_binding
      binding = @event.rfid_bindings.find_by(id: params[:id])
      return render json: { error: 'Binding not found' }, status: :not_found if binding.nil?

      if params[:ticket_public_id].blank? && params[:tag_key].blank?
        return unprocessable('ticket_public_id or tag_key is required')
      end

      admin.update_binding!(binding, ticket_public_id: params[:ticket_public_id].to_s.presence,
                                     tag_key: params[:tag_key].to_s.presence)
      render json: { binding: report.bindings.find { |row| row[:id] == binding.id } }, status: :ok
    end

    def destroy_binding
      binding = @event.rfid_bindings.find_by(id: params[:id])
      return render json: { error: 'Binding not found' }, status: :not_found if binding.nil?

      admin.delete_binding!(binding)
      render json: { deleted: true }, status: :ok
    end

    # `ids` = only those readings; `all: true` = every current anomaly.
    def dismiss_anomalies
      return unprocessable('ids or all is required') unless anomaly_selection?

      render json: { affected: admin.dismiss_anomalies!(ids: anomaly_ids) }, status: :ok
    end

    def destroy_anomalies
      return unprocessable('ids or all is required') unless anomaly_selection?

      render json: { affected: admin.delete_anomalies!(ids: anomaly_ids) }, status: :ok
    end

    private

    def anomaly_all?
      params[:all].to_s == 'true'
    end

    def anomaly_selection?
      anomaly_all? || (params[:ids].is_a?(Array) && params[:ids].any?)
    end

    # nil means every anomaly.
    def anomaly_ids
      anomaly_all? ? nil : params[:ids]
    end

    def admin
      ::Rfid::Admin.new(@event)
    end

    def authorize_admin!
      authorize @event, :rfid_admin?
    end

    def require_staff_session!
      return if current_user.present? && !authenticated_via_api_key

      render json: {
        success: false,
        message: 'This endpoint requires a signed-in user; API keys cannot manage RFID.',
        errors: []
      }, status: :forbidden
    end

    def set_event
      @event = Event.find(params[:event_id])
    end

    def authorize_read!
      authorize @event, :analytics?
    end

    def authorize_update!
      authorize @event, :update?
    end

    def report
      @report ||= ::Rfid::Report.new(@event)
    end

    def settings_payload
      {
        event_id: @event.id,
        rfid_mode: @event.rfid_mode,
        require_check_in: @event.rfid_require_check_in
      }
    end

    def parse_time(value)
      return nil if value.blank?

      Time.iso8601(value.to_s).utc
    rescue ArgumentError
      nil
    end

    def unprocessable(message)
      render json: { success: false, message: message, errors: [] },
             status: :unprocessable_content
    end
  end
end
