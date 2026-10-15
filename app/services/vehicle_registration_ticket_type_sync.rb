class VehicleRegistrationTicketTypeSync
  Error = Class.new(StandardError)

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
    return if vehicle.base_ticket_type_id == @ticket.ticket_type_id

    rule_slug = VehicleRegistrationRules.form_slug_for_base_ticket(@ticket.ticket_type.name)
    return if rule_slug.blank?

    # Same category (e.g. Member -> Non-Member): the car keeps its group.
    if VehicleRegistrationRules.rule_slug(vehicle.registration_form.slug) == rule_slug
      return vehicle.update!(base_ticket_type: @ticket.ticket_type)
    end

    if vehicle.active_tickets.where.not(id: @ticket.id).exists?
      raise Error, 'Cannot change a vehicle category while it has additional active participants'
    end

    vehicle.update!(registration_form: target_form(rule_slug), base_ticket_type: @ticket.ticket_type)
  end

  private

  # Expedition is split into sub-forms (expedition-a-tags-on..h) sharing one
  # rule set, so the ticket type alone may not pick the group — fail loudly
  # rather than leave the car in its old category.
  def target_form(rule_slug)
    forms = @ticket.event.registration_forms.select { |f| VehicleRegistrationRules.rule_slug(f.slug) == rule_slug }
    linked = forms.select { |f| f.ticket_types.exists?(id: @ticket.ticket_type_id) }
    forms = linked if linked.any?
    return forms.first if forms.one?

    raise Error, 'No registration form matches this ticket type' if forms.empty?

    raise Error, 'This ticket type is used by several expedition groups — choose the expedition group too'
  end
end
