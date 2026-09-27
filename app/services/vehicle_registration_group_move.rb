# Moves a whole car to another vehicle group (registration form). Shared by
# V1::TicketsController (panel ticket edit) and V1::VehicleRegistrationsController.
#
# Only a car whose sole active crew member is `ticket` may move — otherwise the
# rest of the crew would change group silently; moving one person out of a crewed
# car means giving them a new plate instead. The mover must hold a base (main
# vehicle) ticket type offered by the target form.
class VehicleRegistrationGroupMove
  class Error < StandardError; end

  def self.call(vehicle:, form:, ticket:)
    new(vehicle: vehicle, form: form, ticket: ticket).call
  end

  def initialize(vehicle:, form:, ticket:)
    @vehicle = vehicle
    @form = form
    @ticket = ticket
  end

  def call
    raise Error, "Choose a valid vehicle group" unless VehicleRegistrationRules.supported?(@form)

    if @vehicle.active_tickets.where.not(id: @ticket.id).exists?
      raise Error, "#{@vehicle.plate} has other crew in #{@vehicle.registration_form.name} — enter a new car plate to move only this person"
    end

    unless VehicleRegistrationRules.new(@form).allowed_ticket_types(nil).exists?(id: @ticket.ticket_type_id)
      raise Error, "Choose a main vehicle ticket type of #{@form.name} to move this car"
    end

    @vehicle.update!(registration_form: @form, base_ticket_type: @ticket.ticket_type)
    @vehicle
  end
end
