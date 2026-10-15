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

    # Only adopt a live vehicle. An archived row with the same plate must not
    # be resurrected — the plate is considered free again, so build a fresh
    # registration for these legacy tickets instead.
    vehicle = VehicleRegistration.active.find_by(event: event, normalized_plate: normalized_plate)
    vehicle ||= VehicleRegistration.create!(
      event: event,
      normalized_plate: normalized_plate,
      registration_form: form,
      base_ticket_type: base_ticket.ticket_type,
      plate: normalized_plate
    )
    Ticket.where(id: tickets.map(&:id)).update_all(vehicle_registration_id: vehicle.id, updated_at: Time.current)
    vehicle
  end
end
