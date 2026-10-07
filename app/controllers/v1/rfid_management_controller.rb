module V1
  # Staff-facing RFID API (P6 target). Every action needs a signed-in user:
  # the event-scoped `rfid` key, and any other API key, is refused here even
  # when the event's policy would otherwise allow the key's owner. Reads use
  # `EventPolicy#analytics?`, settings and corrections use `#update?`.
  class RfidManagementController < ApplicationController
    before_action :require_staff_session!
    before_action :set_event
    before_action :authorize_read!, only: %i[summary stations bindings visits report_xlsx report_fields anomalies missed_scans
                                             flow sessions eligibility eligibility_fields attendance_check session_attendees guest_visits display_activity]
    before_action :authorize_update!, only: %i[update_settings update_station manual_exit manual_exit_all undo_manual_exit_all manual_entry notify_attendance_check grant_cert_override revoke_cert_override bulk_cert_override
                                               create_session update_session destroy_session]
    before_action :authorize_admin!, only: %i[destroy_station update_binding destroy_binding destroy_visit destroy_guest_visits
                                              dismiss_anomalies destroy_anomalies]

    rescue_from ::Rfid::Admin::Error do |error|
      render json: { success: false, message: error.message, errors: [] }, status: error.status
    end

    def summary
      render json: report.summary(ticket_type_id: params[:ticket_type_id].presence), status: :ok
    end

    def stations
      render json: { stations: report.stations }, status: :ok
    end

    def bindings
      status = params[:status].to_s.presence
      unless status.nil? || ::Rfid::Report::BINDING_STATUSES.include?(status)
        return unprocessable("status must be one of #{::Rfid::Report::BINDING_STATUSES.join(', ')}")
      end

      scope = report.bindings_scope(status: status, query: params[:q].to_s.presence,
                                    ticket_type_id: params[:ticket_type_id].presence)
      pagy, rows = pagy(scope, limit: pagination_params[:per_page] || 25)

      render json: { bindings: rows.map { |row| report.binding_row(row) },
                     ticket_types: report.ticket_types, pagination: pagy_metadata(pagy) },
             status: :ok
    end

    def visits
      pagy, visits = pagy(report.visits_scope, limit: pagination_params[:per_page] || 25)

      render json: { visits: report.visit_rows(visits), pagination: pagy_metadata(pagy) },
             status: :ok
    end

    def display_activity
      mode = params[:mode].presence || 'in'
      return unprocessable('mode must be in, out or both') unless ::Rfid::Report::DISPLAY_MODES.include?(mode)

      render json: { activity: report.display_activity(mode: mode) }, status: :ok
    end

    def guest_visits
      status = params[:status].to_s.presence
      unless status.nil? || ::Rfid::Report::GUEST_STATUSES.include?(status)
        return unprocessable("status must be one of #{::Rfid::Report::GUEST_STATUSES.join(', ')}")
      end

      per_page = (pagination_params[:per_page] || 25).to_i
      page = [(pagination_params[:page] || 1).to_i, 1].max
      guests, total = report.guest_visits(status: status, query: params[:q].to_s.presence,
                                          ticket_type_id: params[:ticket_type_id].presence,
                                          page: page, per_page: per_page)
      pages = [(total / per_page.to_f).ceil, 1].max

      render json: {
        guests: guests,
        ticket_types: report.ticket_types,
        pagination: { current_page: page, total_pages: pages, total_count: total, per_page: per_page,
                      prev_page: page > 1 ? page - 1 : nil, next_page: page < pages ? page + 1 : nil }
      }, status: :ok
    end

    # Custom fields staff can add as extra columns to the report.
    def report_fields
      render json: { fields: ::Rfid::ReportWorkbook.custom_fields(@event).map { |key, label| { key: key, label: label } } },
             status: :ok
    end

    def report_xlsx
      send_data ::Rfid::ReportWorkbook.new(@event, fields: Array(params[:fields])).call,
                filename: "rfid-report-event-#{@event.id}.xlsx",
                type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                disposition: 'attachment'
    end

    def missed_scans
      reason = params[:reason].to_s.presence
      unless reason.nil? || ::Rfid::Report::MISSED_REASONS.include?(reason)
        return unprocessable("reason must be one of #{::Rfid::Report::MISSED_REASONS.join(', ')}")
      end

      scope = report.missed_scans_scope(reason, query: params[:q].to_s.presence,
                                                ticket_type_id: params[:ticket_type_id].presence)
      pagy, tickets = pagy(scope, limit: pagination_params[:per_page] || 25)

      render json: {
        tickets: report.missed_scan_rows(tickets),
        ticket_types: @event.ticket_types.order(:name).map { |type| { id: type.id, name: type.name } },
        pagination: pagy_metadata(pagy)
      }, status: :ok
    end

    def flow
      from = params[:from].present? ? parse_time(params[:from]) : nil
      to = params[:to].present? ? parse_time(params[:to]) : nil
      return unprocessable('from and to must be RFC3339 timestamps') if (params[:from].present? && from.nil?) ||
                                                                       (params[:to].present? && to.nil?)
      return unprocessable('from must be before to') if from && to && from >= to

      render json: report.flow(from: from, to: to), status: :ok
    end

    def sessions
      render json: { sessions: attendance.sessions, attendance_percent: @event.rfid_attendance_percent,
                     eligibility: attendance.eligibility_summary }, status: :ok
    end

    def session_attendees
      session = @event.rfid_sessions.find_by(id: params[:id])
      return render json: { error: 'Session not found' }, status: :not_found if session.nil?

      status = params[:status].to_s.presence
      unless status.nil? || %w[attended partial].include?(status)
        return unprocessable('status must be attended or partial')
      end

      rows, counts = attendance.session_attendees(session, status: status, query: params[:q].to_s.presence,
                                                  ticket_type_id: params[:ticket_type_id].presence)
      per_page = (pagination_params[:per_page] || 25).to_i
      page = [(pagination_params[:page] || 1).to_i, 1].max
      pages = [(rows.length / per_page.to_f).ceil, 1].max

      render json: {
        session: attendance.sessions.find { |row| row[:id] == session.id },
        counts: counts,
        ticket_types: attendance.ticket_types,
        attendees: rows.slice((page - 1) * per_page, per_page) || [],
        pagination: { current_page: page, total_pages: pages, total_count: rows.length,
                      per_page: per_page, prev_page: page > 1 ? page - 1 : nil,
                      next_page: page < pages ? page + 1 : nil }
      }, status: :ok
    end

    def eligibility
      rows = filtered_eligibility_rows
      return if performed?

      per_page = (pagination_params[:per_page] || 25).to_i
      page = [(pagination_params[:page] || 1).to_i, 1].max
      pages = [(rows.length / per_page.to_f).ceil, 1].max

      render json: {
        tickets: rows.slice((page - 1) * per_page, per_page) || [],
        ticket_types: attendance.ticket_types,
        sessions: attendance.sessions.select { |row| row[:mandatory] },
        pagination: { current_page: page, total_pages: pages, total_count: rows.length,
                      per_page: per_page, prev_page: page > 1 ? page - 1 : nil,
                      next_page: page < pages ? page + 1 : nil }
      }, status: :ok
    end

    # Custom registration fields (category, agency...) the bulk waive can filter by.
    def eligibility_fields
      render json: { fields: attendance.custom_field_options }, status: :ok
    end

    # Waive the session rule for every guest who matches the same filters as the
    # eligibility list and is still short (already-waived and already-met guests
    # are skipped). `dry_run` only reports how many guests that is.
    def bulk_cert_override
      rows = filtered_eligibility_rows
      return if performed?

      targets = rows.select { |row| row[:override].nil? && row[:sessions].any? { |item| !item[:met] } }
      return render json: bulk_preview(targets), status: :ok if bool_param(:dry_run)

      reason = params[:reason].to_s.strip
      return unprocessable('A reason is required.') if reason.empty?

      ::Rfid::Correction.transaction do
        targets.each do |row|
          ::Rfid::Correction.create!(event: @event, actor: current_user, ticket_id: row[:id],
                                     kind: 'cert_override', reason: reason)
        end
      end
      render json: { count: targets.length, dry_run: false }, status: :ok
    end

    def create_session
      session = @event.rfid_sessions.new(session_params)
      session.save!
      render json: { session: attendance.sessions.find { |row| row[:id] == session.id } },
             status: :created
    rescue ActiveRecord::RecordInvalid => e
      unprocessable(e.record.errors.full_messages.to_sentence)
    end

    def update_session
      session = @event.rfid_sessions.find_by(id: params[:id])
      return render json: { error: 'Session not found' }, status: :not_found if session.nil?

      session.update!(session_params)
      render json: { session: attendance.sessions.find { |row| row[:id] == session.id } }, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      unprocessable(e.record.errors.full_messages.to_sentence)
    end

    def destroy_session
      session = @event.rfid_sessions.find_by(id: params[:id])
      return render json: { error: 'Session not found' }, status: :not_found if session.nil?

      session.destroy!
      render json: { deleted: true }, status: :ok
    end

    def anomalies
      scope = report.filter_anomalies(report.anomaly_observations, query: params[:q].to_s.presence,
                                                                    outcome: params[:outcome].to_s.presence,
                                                                    station: params[:station].to_s.presence)
      pagy, observations = pagy(scope, limit: pagination_params[:per_page] || 25)

      render json: {
        stations: report.station_keys,
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

      if params.key?(:attendance_percent)
        percent = params[:attendance_percent]
        unless percent.is_a?(Integer) && percent.between?(1, 100)
          return unprocessable('attendance_percent must be a whole number from 1 to 100')
        end

        attributes[:rfid_attendance_percent] = percent
      end

      return unprocessable('rfid_mode, require_check_in or attendance_percent is required') if attributes.empty?

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

    # End-of-day sweep: close every open visit (optionally one ticket type) at
    # one time, one correction each, so the headcount stops counting guests
    # who left without tapping out. Manual-entry visits have no entry reading
    # to correct against and are left for their own exit.
    def manual_exit_all
      reason = params[:reason].to_s.strip
      return unprocessable('A reason is required.') if reason.empty?

      at = parse_time(params[:at])
      return unprocessable('at must be an RFC3339 timestamp') if at.nil?
      return unprocessable('The time cannot be in the future.') if at > 1.minute.from_now

      closed = 0
      batch = SecureRandom.uuid
      @event.with_lock do
        visits = @event.rfid_visits.open.where.not(entry_observation_id: nil).where(entry_at: ..at)
        type_id = params[:ticket_type_id].presence
        visits = visits.where(ticket_id: @event.tickets.where(ticket_type_id: type_id).select(:id)) if type_id
        visits = visits.to_a
        visits.each do |visit|
          ::Rfid::Correction.create!(
            event: @event, actor: current_user, entry_observation_id: visit.entry_observation_id,
            kind: 'manual_exit', exit_at: at, reason: reason,
            details: { 'entry_observation_id' => visit.entry_observation_id, 'batch' => batch }
          )
        end
        ::Rfid::Visits.rebuild!(event: @event, ticket_ids: visits.map(&:ticket_id).compact.uniq)
        closed = visits.size
      end

      render json: { closed: closed }, status: :ok
    end

    # Takes back the newest sweep: its corrections go, and those guests are
    # rebuilt as inside again (unless a real gate exit has closed them since).
    def undo_manual_exit_all
      reopened = 0
      @event.with_lock do
        batch = report.last_bulk_exit&.dig(:batch)
        return unprocessable('There is no bulk exit to undo.') if batch.nil?

        corrections = report.bulk_exit_scope(batch)
        ticket_ids = @event.rfid_observations.where(id: corrections.select(:entry_observation_id))
                           .distinct.pluck(:ticket_id).compact
        reopened = corrections.delete_all
        ::Rfid::Visits.rebuild!(event: @event, ticket_ids: ticket_ids)
      end

      render json: { reopened: reopened }, status: :ok
    end

    # Who the gates may have missed, and the webhook that lets the event's
    # receiver (SalesCatalyst) reach them on WhatsApp.
    def attendance_check
      render json: attendance_check_for(params[:ticket_type_ids]).summary, status: :ok
    end

    def notify_attendance_check
      reasons = Array(params[:reasons]).map(&:to_s).uniq
      if reasons.empty? || (reasons - ::Rfid::AttendanceCheck::REASONS).any?
        return unprocessable("reasons must be from #{::Rfid::AttendanceCheck::REASONS.join(', ')}")
      end
      return unprocessable('This event has no webhook URL configured.') if @event.webhook_urls.empty?

      render json: attendance_check_for(params[:ticket_type_ids]).notify!(reasons: reasons, actor: current_user),
             status: :ok
    end

    # Add a visit the gate never recorded (gate offline, sticker unread). With
    # no `exit_at` the guest is still inside and their next real exit closes it.
    # A correction, not a synthetic reading, so it survives every rebuild.
    def manual_entry
      ticket = @event.tickets.active.paid.find_by(public_id: params[:ticket_public_id].to_s)
      return render json: { error: 'Ticket not found' }, status: :not_found if ticket.nil?

      reason = params[:reason].to_s.strip
      return unprocessable('A reason is required.') if reason.empty?

      entry_at = parse_time(params[:entry_at])
      return unprocessable('entry_at must be an RFC3339 timestamp') if entry_at.nil?

      exit_at = parse_time(params[:exit_at])
      return unprocessable('exit_at must be an RFC3339 timestamp') if params[:exit_at].present? && exit_at.nil?
      return unprocessable('The entry must be before the exit.') if exit_at && entry_at >= exit_at
      return unprocessable('The time cannot be in the future.') if (exit_at || entry_at) > 1.minute.from_now

      correction = nil
      @event.with_lock do
        overlap = @event.rfid_visits.where(ticket_id: ticket.id)
                        .where('entry_at < ? AND COALESCE(exit_at, ?) > ?', exit_at || Time.current,
                               Time.current, entry_at).exists?
        return unprocessable('This guest already has a visit during that time.') if overlap

        correction = ::Rfid::Correction.create!(
          event: @event, actor: current_user, ticket: ticket, kind: 'manual_entry',
          exit_at: exit_at, reason: reason, details: { 'entry_at' => entry_at.iso8601(6) }
        )
        ::Rfid::Visits.rebuild!(event: @event)
      end

      render json: { visit: report.visit_row(@event.rfid_visits.find_by!(correction_id: correction.id)) }, status: :ok
    end

    # Waive the session attendance rule for one guest (e.g. left early for
    # logistics). Feedback is still required; the grant is an audited correction.
    def grant_cert_override
      set_cert_override('cert_override', require_reason: true)
    end

    def revoke_cert_override
      set_cert_override('cert_override_revoked', require_reason: false)
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
      render json: { binding: report.binding_row(binding.reload) }, status: :ok
    end

    def destroy_binding
      binding = @event.rfid_bindings.find_by(id: params[:id])
      return render json: { error: 'Binding not found' }, status: :not_found if binding.nil?

      admin.delete_binding!(binding)
      render json: { deleted: true }, status: :ok
    end

    def destroy_visit
      visit = @event.rfid_visits.find_by(id: params[:id])
      return render json: { error: 'Visit not found' }, status: :not_found if visit.nil?

      admin.delete_visit!(visit)
      render json: { deleted: true }, status: :ok
    end

    def destroy_guest_visits
      render json: { deleted: admin.delete_guest_visits!(params[:ticket_id].to_i) }, status: :ok
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

    # `ids` nil means every ticket type; a list (even empty) narrows to it.
    def attendance_check_for(ids)
      ids = Array(ids).map(&:to_i) unless ids.nil?
      ::Rfid::AttendanceCheck.new(@event, ticket_type_ids: ids)
    end

    def set_cert_override(kind, require_reason:)
      ticket = @event.tickets.active.paid.find_by(id: params[:ticket_id])
      return render json: { error: 'Ticket not found' }, status: :not_found if ticket.nil?

      reason = params[:reason].to_s.strip
      return unprocessable('A reason is required.') if require_reason && reason.empty?

      ::Rfid::Correction.create!(event: @event, actor: current_user, ticket: ticket, kind: kind,
                                 reason: reason.presence || 'override removed')
      render json: { ticket: attendance.eligibility_rows.find { |row| row[:id] == ticket.id } }, status: :ok
    end

    # Shared by the eligibility list and the bulk waive so "waive everyone shown"
    # means exactly the rows the filters select. A bad filter renders a 422;
    # callers must check `performed?` before using the result.
    def filtered_eligibility_rows
      status = params[:status].to_s.presence
      unless status.nil? || ::Rfid::Attendance::STATUSES.include?(status)
        return unprocessable("status must be one of #{::Rfid::Attendance::STATUSES.join(', ')}")
      end

      min_percent = params[:min_percent].presence
      if min_percent && !min_percent.to_s.match?(/\A\d{1,3}(\.\d+)?\z/)
        return unprocessable('min_percent must be a number between 0 and 100')
      end

      rows = attendance.filter_rows(attendance.eligibility_rows, query: params[:q].to_s.presence,
                                                                 ticket_type_id: params[:ticket_type_id].presence,
                                                                 custom_fields: custom_field_filters)
      rows = rows.select { |row| row[:status] == status } if status
      # Lowest session percent at least this value: the near-miss guests.
      rows = rows.select { |row| row[:sessions].all? { |item| item[:percent] >= min_percent.to_f } } if min_percent
      rows
    end

    # { "category" => "Agensi" } from `custom_fields[category]=Agensi`; keys that
    # aren't plain identifiers are dropped.
    def custom_field_filters
      raw = params[:custom_fields]
      return nil unless raw.respond_to?(:to_unsafe_h)

      raw.to_unsafe_h.select { |key, value| key.to_s.match?(/\A[a-z0-9_]+\z/i) && value.is_a?(String) && value.present? }
    end

    BULK_PREVIEW_LIMIT = 200

    # The guests a bulk waive would touch (first page only, the count is exact).
    def bulk_preview(targets)
      guests = targets.first(BULK_PREVIEW_LIMIT).map do |row|
        { id: row[:id], ticket_name: row[:ticket_name], ticket_public_id: row[:ticket_public_id],
          ticket_type: row[:ticket_type], feedback_submitted: row[:feedback_submitted],
          lowest_percent: row[:sessions].map { |item| item[:percent] }.min }
      end
      { count: targets.length, dry_run: true, guests: guests, limit: BULK_PREVIEW_LIMIT }
    end

    def bool_param(key)
      ActiveModel::Type::Boolean.new.cast(params[key]) || false
    end

    def attendance
      @attendance ||= ::Rfid::Attendance.new(@event)
    end

    def session_params
      params.permit(:name, :starts_at, :ends_at, :mandatory)
    end

    def report
      @report ||= ::Rfid::Report.new(@event)
    end

    def settings_payload
      {
        event_id: @event.id,
        rfid_mode: @event.rfid_mode,
        require_check_in: @event.rfid_require_check_in,
        attendance_percent: @event.rfid_attendance_percent
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
