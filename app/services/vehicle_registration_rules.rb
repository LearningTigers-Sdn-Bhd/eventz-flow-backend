class VehicleRegistrationRules
  class UnsupportedForm < StandardError; end

  FORM_RULES = {
    'expedition-tags-on' => {
      capacity: 4,
      base: [
        'Expedition - Member',
        'Expedition - Corporate',
        'Expedition - Non-Member',
        'Expedition - International'
      ],
      included_second: ['Expedition - Member', 'Expedition - Corporate'],
      included_ticket: 'Included 2nd Person - Member/Corporate',
      additional: ['Additional Person - Member', 'Additional Person - Non-Member'],
      non_member_ticket: 'Additional Person - Non-Member'
    },
    'competition' => {
      capacity: 3,
      base: [
        'Competition - Member',
        'Competition - Non-Member',
        'Competition - Corporate',
        'Competition - International'
      ],
      included_second: :all,
      included_ticket: 'Included 2nd Person (Team of 2)',
      additional: [
        'Reserve Co-Driver - Member',
        'Reserve Co-Driver - Non-Member/International/Corporate'
      ]
    },
    'competitor-support' => {
      capacity: 4,
      base: ['Support - Member', 'Support - Non-Member'],
      included_second: ['Support - Member'],
      included_ticket: 'Included 2nd Person - Member/Corporate',
      additional: ['Additional Person - Member', 'Additional Person - Non-Member'],
      non_member_ticket: 'Additional Person - Non-Member'
    }
  }.freeze

  attr_reader :form

  def self.form_slug_for_base_ticket(ticket_name)
    FORM_RULES.find { |_slug, config| config.fetch(:base).include?(ticket_name) }&.first
  end

  def initialize(form)
    @form = form
    raise UnsupportedForm, 'Vehicle registration is not used for this form' unless rule
  end

  def capacity
    rule.fetch(:capacity)
  end

  def allowed_ticket_types(vehicle_registration)
    names = allowed_ticket_names(vehicle_registration)
    form.ticket_types.where(name: names).order(:id)
  end

  def allowed_ticket_names(vehicle_registration)
    return rule.fetch(:base) unless vehicle_registration

    occupancy = vehicle_registration.active_tickets.count
    return rule.fetch(:base) if occupancy.zero?
    return [] if occupancy >= capacity

    base_name = vehicle_registration.base_ticket_type.name
    if occupancy == 1
      included = rule.fetch(:included_second)
      return [rule.fetch(:included_ticket)] if included == :all || included.include?(base_name)
      return [rule.fetch(:non_member_ticket)] if rule[:non_member_ticket]
    end

    rule.fetch(:additional)
  end

  def status(vehicle_registration)
    return 'new' unless vehicle_registration
    return 'full' if vehicle_registration.active_tickets.count >= capacity

    'existing'
  end

  def invalid_ticket_message(vehicle_registration)
    return 'Choose a main vehicle ticket for a new car plate' unless vehicle_registration

    if vehicle_registration.active_tickets.count == 1 &&
       allowed_ticket_names(vehicle_registration) == [rule[:included_ticket]]
      return 'The included second person must use the free included ticket'
    end

    'This ticket is not available for the next person in this vehicle'
  end

  private

  def rule
    FORM_RULES[form.slug]
  end
end
