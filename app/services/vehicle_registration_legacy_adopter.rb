class VehicleRegistrationLegacyAdopter
  PLATE_SQL = <<~SQL.squish.freeze
    regexp_replace(
      upper(coalesce(custom_fields_data->>'car_registration_number', '')),
      '[^A-Z0-9]',
      '',
      'g'
    ) = ?
  SQL

  def self.call(event:, normalized_plate:)
    tickets = event.tickets
                   .where(vehicle_registration_id: nil)
                   .where(PLATE_SQL, normalized_plate)
                   .includes(:ticket_type)
                   .order(:id)
                   .to_a
    return if tickets.empty?

    base_ticket = tickets.find do |ticket|
      VehicleRegistrationRules.form_slug_for_base_ticket(ticket.ticket_type.name)
    end
    return unless base_ticket

    form_slug = VehicleRegistrationRules.form_slug_for_base_ticket(base_ticket.ticket_type.name)
    # Expedition is split into sub-forms (expedition-a-tags-on..h), so match on
    # the shared rule slug and the ticket type rather than an exact slug.
    form = event.registration_forms.active
                .joins(:registration_form_ticket_types)
                .where(registration_form_ticket_types: { ticket_type_id: base_ticket.ticket_type_id })
                .find { |f| VehicleRegistrationRules.rule_slug(f.slug) == form_slug }
    return unless form

    vehicle = VehicleRegistration.create_or_find_by!(
      event: event,
      normalized_plate: normalized_plate
    ) do |record|
      record.registration_form = form
      record.base_ticket_type = base_ticket.ticket_type
      record.plate = normalized_plate
    end
    Ticket.where(id: tickets.map(&:id)).update_all(vehicle_registration_id: vehicle.id, updated_at: Time.current)
    vehicle
  end
end
