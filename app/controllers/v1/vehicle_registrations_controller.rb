module V1
  # Staff-facing list of an event's cars and their crew, with per-car data
  # issues (see VehicleRegistrationAudit) and one-click fixes. Only available
  # when the event has vehicles_enabled. Authorized like a ticket update —
  # every action here edits ticket/vehicle data.
  class VehicleRegistrationsController < ApplicationController
    before_action :set_event
    before_action :authorize_manage!
    before_action :authorize_owner!, only: %i[destroy]
    before_action :ensure_vehicles_enabled!
    before_action :set_vehicle, only: %i[move_group sync_base update archive restore destroy]
    before_action :ensure_no_active_crew!, only: %i[archive destroy]

    # GET /v1/events/:event_id/vehicle_registrations
    # Query params:
    #   - issues_only=true: only cars with at least one detected issue.
    #   - q: matches the plate or a crew member's name (case-insensitive substring).
    #   - registration_form_id: only cars in that group.
    def index
      vehicles = @event.vehicle_registrations
                       .includes(:base_ticket_type, registration_form: :ticket_types, tickets: :ticket_type)
                       .order(:plate)

      vehicles =
        case params[:archived]
        when 'true' then vehicles.archived
        when 'all' then vehicles
        else vehicles.active
        end

      vehicles = vehicles.where(registration_form_id: params[:registration_form_id]) if params[:registration_form_id].present?

      payload = vehicles.map { |vehicle| vehicle_payload(vehicle) }

      if params[:q].present?
        query = params[:q].strip.downcase
        payload = payload.select do |car|
          car[:plate].downcase.include?(query) || car[:crew].any? { |member| member[:name].downcase.include?(query) }
        end
      end

      payload = payload.select { |car| car[:issues].any? } if params[:issues_only] == 'true'

      render json: payload, status: :ok
    end

    # PATCH /v1/events/:event_id/vehicle_registrations/:id/move_group
    def move_group
      form = @event.registration_forms.find_by(id: params[:registration_form_id])
      mover = VehicleRegistrationAudit.crew_for(@vehicle).first
      return render_errors(['This car has no active crew to move']) if mover.nil?

      VehicleRegistrationGroupMove.call(vehicle: @vehicle, form: form, ticket: mover)
      render json: vehicle_payload(@vehicle.reload), status: :ok
    rescue VehicleRegistrationGroupMove::Error => e
      render_errors([e.message])
    rescue ActiveRecord::RecordInvalid => e
      render_errors(e.record.errors.full_messages)
    end

    # PATCH /v1/events/:event_id/vehicle_registrations/:id/sync_base
    def sync_base
      audit = VehicleRegistrationAudit.new(@vehicle)
      holder = audit.base_holder
      return render_errors(['No crew member holds a main vehicle ticket for this group']) unless holder
      if audit.ambiguous_base?
        return render_errors(['More than one crew member holds a main vehicle ticket — fix the tickets first'])
      end

      @vehicle.update!(base_ticket_type: holder.ticket_type)
      render json: vehicle_payload(@vehicle.reload), status: :ok
    rescue ActiveRecord::RecordInvalid => e
      render_errors(e.record.errors.full_messages)
    end

    # PATCH /v1/events/:event_id/vehicle_registrations/:id
    # Renames the plate. The plate is mirrored onto each crew ticket's
    # car_registration_number custom field (it's how legacy adoption and
    # on-site lookups find a car), so keep both copies in sync atomically.
    def update
      return render_errors(['Archived vehicles cannot be renamed — restore it first']) if @vehicle.archived?

      plate = VehicleRegistration.normalize_plate(params[:plate])
      return render_errors(['Car plate number is required']) if plate.blank?

      VehicleRegistration.transaction do
        @vehicle.update!(plate: plate, normalized_plate: plate)
        @vehicle.tickets.find_each do |ticket|
          ticket.update!(custom_fields_data: ticket.custom_fields_data.to_h.merge('car_registration_number' => plate))
        end
      end
      render json: vehicle_payload(@vehicle.reload), status: :ok
    rescue ActiveRecord::RecordInvalid => e
      render_errors(e.record.errors.full_messages)
    end

    # PATCH /v1/events/:event_id/vehicle_registrations/:id/archive
    def archive
      @vehicle.update!(deleted_at: Time.current)
      render json: vehicle_payload(@vehicle.reload), status: :ok
    rescue ActiveRecord::RecordInvalid => e
      render_errors(e.record.errors.full_messages)
    end

    # PATCH /v1/events/:event_id/vehicle_registrations/:id/restore
    def restore
      @vehicle.update!(deleted_at: nil)
      render json: vehicle_payload(@vehicle.reload), status: :ok
    rescue ActiveRecord::RecordInvalid => e
      render_errors(e.record.errors.full_messages)
    end

    # DELETE /v1/events/:event_id/vehicle_registrations/:id
    # Permanent remove. Crew tickets are kept — the FK nullifies and they
    # simply become unattached from any car (dependent: :nullify).
    def destroy
      @vehicle.destroy!
      render json: { deleted: true }, status: :ok
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    # Crew names, plates and payment state are staff data — same rule as
    # editing a ticket, not EventPolicy#show? (true for any published event).
    def authorize_manage!
      authorize Ticket.new(event: @event), :update?
    end

    # Permanent delete is destructive in a way archive isn't — restrict it to
    # org owners, same bar as force-deleting a ticket.
    # Archiving/deleting a car with crew leaves their tickets pointing at a
    # hidden car (or none) while still carrying its plate — make staff move
    # or cancel the crew first.
    def ensure_no_active_crew!
      count = VehicleRegistrationAudit.crew_for(@vehicle).size
      return if count.zero?

      render_errors(["Vehicle still has #{count} active crew — move or cancel them first"])
    end

    def authorize_owner!
      return if current_user.is_org_owner?

      render json: { errors: ['Only organization owners can permanently delete vehicles'] },
             status: :forbidden
    end

    def ensure_vehicles_enabled!
      render json: { errors: ['Not found'] }, status: :not_found unless @event.vehicles_enabled?
    end

    def set_vehicle
      @vehicle = @event.vehicle_registrations
                       .includes(:base_ticket_type, registration_form: :ticket_types, tickets: :ticket_type)
                       .find(params[:id])
    end

    def vehicle_payload(vehicle)
      crew = VehicleRegistrationAudit.crew_for(vehicle)
      rules = VehicleRegistrationRules.supported?(vehicle.registration_form) ? VehicleRegistrationRules.new(vehicle.registration_form) : nil

      {
        id: vehicle.id,
        plate: vehicle.plate,
        deleted_at: vehicle.deleted_at,
        registration_form: {
          id: vehicle.registration_form&.id,
          name: vehicle.registration_form&.name,
          slug: vehicle.registration_form&.slug
        },
        base_ticket_type: {
          id: vehicle.base_ticket_type&.id,
          name: vehicle.base_ticket_type&.name
        },
        capacity: rules&.capacity,
        seats_used: crew.size,
        crew: crew.map { |ticket| crew_payload(ticket) },
        issues: VehicleRegistrationAudit.call(vehicle, crew: crew).map { |issue| issue_payload(issue) }
      }
    end

    def crew_payload(ticket)
      {
        ticket_id: ticket.id,
        public_id: ticket.public_id,
        name: ticket.attendee_name,
        role: ticket.role,
        ticket_type_name: ticket.ticket_type&.name,
        status: ticket.status,
        payment_status: ticket.payment_status
      }
    end

    def issue_payload(issue)
      payload = { code: issue.code, message: issue.message }
      payload[:ticket_id] = issue.ticket_id if issue.ticket_id
      payload
    end

    def render_errors(errors)
      render json: { errors: errors }, status: :unprocessable_content
    end
  end
end
