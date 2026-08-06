class VehicleRegistrationAssignment
  class Error < StandardError; end

  VEHICLE_PLATE_INDEX = 'idx_vehicle_registrations_event_plate'.freeze

  def initialize(event:, form:, ticket:, plate:)
    @event = event
    @form = form
    @ticket = ticket
    @plate = VehicleRegistration.normalize_plate(plate)
    @rules = VehicleRegistrationRules.new(form)
  end

  def save
    raise Error, 'Car plate number is required' if @plate.blank?

    saved = false
    VehicleRegistration.transaction do
      vehicle = find_or_create_vehicle!
      vehicle.lock!

      if vehicle.registration_form_id != @form.id
        raise Error, "This car plate is already registered under #{vehicle.registration_form.name}"
      end

      allowed_ids = @rules.allowed_ticket_types(vehicle).pluck(:id)
      unless allowed_ids.include?(@ticket.ticket_type_id)
        raise Error, @rules.invalid_ticket_message(vehicle)
      end

      vehicle.update!(base_ticket_type: @ticket.ticket_type) unless vehicle.active_tickets.exists?

      @ticket.vehicle_registration = vehicle
      @ticket.custom_fields_data = @ticket.custom_fields_data.to_h.merge(
        'car_registration_number' => vehicle.plate
      )
      saved = @ticket.save
      raise ActiveRecord::Rollback unless saved
    end
    saved
  rescue ActiveRecord::RecordNotUnique => e
    raise unless [e.message, e.cause&.message].compact.any? { |message| message.include?(VEHICLE_PLATE_INDEX) }

    retry
  end

  private

  def find_or_create_vehicle!
    existing = VehicleRegistration.find_by(event: @event, normalized_plate: @plate)
    existing ||= VehicleRegistrationLegacyAdopter.call(event: @event, normalized_plate: @plate)
    return existing if existing

    allowed_base_ids = @rules.allowed_ticket_types(nil).pluck(:id)
    raise Error, @rules.invalid_ticket_message(nil) unless allowed_base_ids.include?(@ticket.ticket_type_id)

    VehicleRegistration.create!(
      event: @event,
      registration_form: @form,
      base_ticket_type: @ticket.ticket_type,
      plate: @plate,
      normalized_plate: @plate
    )
  end
end
