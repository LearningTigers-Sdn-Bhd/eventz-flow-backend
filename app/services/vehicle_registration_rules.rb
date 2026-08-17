class VehicleRegistrationRules
  class UnsupportedForm < StandardError; end

  TERMS_METHOD = 'checkbox_typed_name'.freeze
  TERMS_VERSION = 'borneo-safari-sabah-registration-terms-v1'.freeze
  REQUIRED_DOCUMENT_KEYS = %w[passport_copy photo_1].freeze

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
      included_second_extra_ticket: 'Additional Person - Non-Member',
      member_base: ['Expedition - Member', 'Expedition - Corporate'],
      additional_member_ticket: 'Additional Person - Member',
      additional_non_member_ticket: 'Additional Person - Non-Member'
    },
    'competition' => {
      capacity: 4,
      base: [
        'Competition - Member',
        'Competition - Non-Member',
        'Competition - Corporate',
        'Competition - International'
      ],
      included_second: :all,
      included_ticket: 'Included 2nd Person (Team of 2)',
      member_base: ['Competition - Member'],
      additional_member_ticket: 'Reserve Co-Driver - Member',
      additional_non_member_ticket: 'Reserve Co-Driver - Non-Member/International/Corporate'
    },
    'competitor-support' => {
      capacity: 4,
      base: ['Support - Member', 'Support - Non-Member', 'Support - Corporate'],
      included_second: ['Support - Member', 'Support - Corporate'],
      included_ticket: 'Included 2nd Person - Member/Corporate',
      included_second_extra_ticket: 'Additional Person - Non-Member',
      member_base: ['Support - Member', 'Support - Corporate'],
      additional_member_ticket: 'Additional Person - Member',
      additional_non_member_ticket: 'Additional Person - Non-Member'
    },
    'official-crew' => {
      capacity: 4,
      base: ['Official Crew - Member', 'Official Crew - Non-Member'],
      # Everything is free, so there's no special "included" ticket for seat 2 —
      # every seat (including the 2nd) picks its own Member/Non-Member ticket.
      included_second: [],
      included_ticket: 'Official Crew - Member',
      member_base: ['Official Crew - Member'],
      additional_member_ticket: 'Official Crew - Member',
      additional_non_member_ticket: 'Official Crew - Non-Member'
    }
  }.freeze

  attr_reader :form

  def self.form_slug_for_base_ticket(ticket_name)
    FORM_RULES.find { |_slug, config| config.fetch(:base).include?(ticket_name) }&.first
  end

  # Expedition split into sub-forms (expedition-a-tags-on..h) that share one rule set.
  def self.rule_slug(slug)
    slug.to_s.start_with?('expedition-') ? 'expedition-tags-on' : slug.to_s
  end

  def self.supported?(form)
    form.present? && FORM_RULES.key?(rule_slug(form.slug))
  end

  def self.supported_slugs(form_slugs)
    form_slugs.select { |slug| FORM_RULES.key?(rule_slug(slug)) }
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
    included = rule.fetch(:included_second)
    qualifies_for_included = included == :all || included.include?(base_name)

    # The free included seat is a one-per-vehicle perk, not tied to seat
    # position — it stays on offer for whichever seat (2nd, 3rd, 4th) claims
    # it first, then disappears once someone has.
    if qualifies_for_included && !included_ticket_claimed?(vehicle_registration)
      return [rule.fetch(:included_ticket), rule[:included_second_extra_ticket]].compact
    end

    return [additional_ticket_name(base_name)] if rule[:lock_additional_to_base]

    additional_ticket_names
  end

  def status(vehicle_registration)
    return 'new' unless vehicle_registration
    return 'full' if vehicle_registration.active_tickets.count >= capacity

    'existing'
  end

  def invalid_ticket_message(vehicle_registration)
    return 'Choose a main vehicle ticket for a new car plate' unless vehicle_registration

    if allowed_ticket_names(vehicle_registration) == [rule[:included_ticket]]
      return 'The included second person must use the free included ticket'
    end

    'This ticket is not available for the next person in this vehicle'
  end

  private

  def included_ticket_claimed?(vehicle_registration)
    vehicle_registration.active_tickets.joins(:ticket_type)
                         .exists?(ticket_types: { name: rule.fetch(:included_ticket) })
  end

  def additional_ticket_names
    [rule.fetch(:additional_member_ticket), rule.fetch(:additional_non_member_ticket)].uniq
  end

  def additional_ticket_name(base_name)
    member_base = rule.fetch(:member_base)
    return rule.fetch(:additional_member_ticket) if member_base.include?(base_name)

    rule.fetch(:additional_non_member_ticket)
  end

  def rule
    FORM_RULES[self.class.rule_slug(form.slug)]
  end
end
