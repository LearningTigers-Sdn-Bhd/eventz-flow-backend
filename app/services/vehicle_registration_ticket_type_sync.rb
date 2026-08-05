class VehicleRegistrationTicketTypeSync
  def self.call(ticket)
    new(ticket).call
  end

  def initialize(ticket)
    @ticket = ticket
  end

  def call
    vehicle = @ticket.vehicle_registration
    previous_ticket_type_id = @ticket.saved_change_to_ticket_type_id&.first
    return unless vehicle && previous_ticket_type_id == vehicle.base_ticket_type_id

    form_slug = VehicleRegistrationRules.form_slug_for_base_ticket(@ticket.ticket_type.name)
    return if form_slug.blank?

    form = @ticket.event.registration_forms.find_by(slug: form_slug)
    return unless form

    return if vehicle.registration_form_id == form.id && vehicle.base_ticket_type_id == @ticket.ticket_type_id

    vehicle.update!(registration_form: form, base_ticket_type: @ticket.ticket_type)
  end
end
