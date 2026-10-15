# Flags cars whose stored data no longer matches VehicleRegistrationRules, so
# staff can fix them from the panel instead of the Rails console. The person
# who registered the car often holds the base ticket without being labelled
# "Driver", so group and base checks compare against the crew member holding a
# base ticket — never against role == "Driver" alone, which false-positives.
class VehicleRegistrationAudit
  Issue = Data.define(:code, :message, :ticket_id)
  INACTIVE_STATUSES = %w[canceled refunded].freeze

  # Active crew from preloaded tickets (no query when `tickets` is loaded).
  def self.crew_for(vehicle)
    vehicle.tickets.reject { |t| INACTIVE_STATUSES.include?(t.status) }
  end

  def self.call(vehicle, crew: nil)
    new(vehicle, crew: crew).call
  end

  def initialize(vehicle, crew: nil)
    @vehicle = vehicle
    @crew = crew || self.class.crew_for(vehicle)
  end

  def call
    return unsupported_issues unless VehicleRegistrationRules.supported?(@vehicle.registration_form)

    [wrong_group_issue, base_issue, *ticket_group_issues].compact
  end

  # The crew member whose ticket should be the car's base: the only base
  # holder, else the base holder marked Driver, else the earliest base holder.
  def base_holder
    holders = base_holders
    holders.find { |t| t.role == 'Driver' } || holders.min_by(&:id)
  end

  # Official Crew uses the same names for base and extra seats, so several
  # holders is normal there; elsewhere it means two main-vehicle tickets.
  def ambiguous_base?
    return false if base_holders.size < 2

    (rule.fetch(:base) & [rule[:additional_member_ticket], rule[:additional_non_member_ticket]]).empty?
  end

  private

  def unsupported_issues
    return [] if @crew.empty?

    [Issue.new(code: :unsupported_form,
               message: "Group #{@vehicle.registration_form&.name} is not a vehicle group",
               ticket_id: nil)]
  end

  def wrong_group_issue
    return nil if @crew.empty?

    driver = base_holder || @crew.find { |t| t.role == 'Driver' } || @crew.first
    want = VehicleRegistrationRules.form_slug_for_base_ticket(driver.ticket_type&.name)
    return nil unless want && want != group

    Issue.new(code: :wrong_group,
              message: "#{driver.attendee_name} holds #{driver.ticket_type.name} but the car is in #{@vehicle.registration_form.name}",
              ticket_id: driver.id)
  end

  def base_issue
    return nil if @crew.empty?

    if base_holders.empty?
      return Issue.new(code: :no_base_holder,
                       message: 'No crew member holds a main vehicle ticket for this group',
                       ticket_id: nil)
    end

    if ambiguous_base?
      return Issue.new(code: :multiple_base_holders,
                       message: "#{base_holders.map(&:attendee_name).join(', ')} all hold a main vehicle ticket — change all but one",
                       ticket_id: nil)
    end

    holder = base_holder
    return nil if @vehicle.base_ticket_type_id == holder.ticket_type_id

    Issue.new(code: :stale_base,
              message: "Base ticket type is #{@vehicle.base_ticket_type&.name} but #{holder.attendee_name} holds #{holder.ticket_type&.name}",
              ticket_id: holder.id)
  end

  def ticket_group_issues
    form_type_ids = @vehicle.registration_form.ticket_types.map(&:id)
    @crew.reject { |t| form_type_ids.include?(t.ticket_type_id) }.map do |ticket|
      Issue.new(code: :ticket_not_in_group,
                message: "#{ticket.attendee_name}'s #{ticket.ticket_type&.name} ticket is not part of #{@vehicle.registration_form.name}",
                ticket_id: ticket.id)
    end
  end

  # Crew members whose ticket type is a base (main vehicle) ticket under the
  # car's current group rule set.
  def base_holders
    @base_holders ||= begin
      base_names = rule ? rule.fetch(:base) : []
      @crew.select { |t| base_names.include?(t.ticket_type&.name) }
    end
  end

  def rule
    VehicleRegistrationRules::FORM_RULES[group]
  end

  def group
    VehicleRegistrationRules.rule_slug(@vehicle.registration_form.slug)
  end
end
