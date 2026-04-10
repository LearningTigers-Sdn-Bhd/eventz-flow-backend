class BorneoExpoTicketUpgradeService
  BORNEO_EVENT_SLUG_PREFIX = 'borneo-expo'.freeze
  COMBINED_TICKET_TYPE_NAME = 'Exhibitor & Conference'.freeze
  TICKET_TYPE_QUANTITY = 99_999

  def self.call(event:, attendee_email:, target_category:)
    new(event:, attendee_email:, target_category:).call
  end

  def initialize(event:, attendee_email:, target_category:)
    @event = event
    @attendee_email = attendee_email
    @target_category = normalize_value(target_category)
  end

  def call
    return unless borneo_event?

    normalized_email = normalize_value(@attendee_email)
    return if normalized_email.blank?

    matching_tickets = @event.tickets
                             .where(attendee_email_norm: normalized_email)
                             .where.not(status: %i[canceled refunded])
                             .includes(:ticket_type)
                             .order(:id)

    combined_ticket = matching_tickets.find { |ticket| combined_ticket_type?(ticket.ticket_type) }
    return combined_ticket if combined_ticket

    source_ticket = matching_tickets.find { |ticket| upgradable_ticket_type?(ticket.ticket_type) }
    return unless source_ticket

    source_ticket.update!(ticket_type: combined_ticket_type)
    source_ticket
  end

  private

  def borneo_event?
    normalized_slug(@event&.slug).start_with?(BORNEO_EVENT_SLUG_PREFIX)
  end

  def upgradable_ticket_type?(ticket_type)
    case @target_category
    when 'conference'
      exhibitor_ticket_type?(ticket_type)
    when 'exhibitor'
      conference_ticket_type?(ticket_type)
    else
      false
    end
  end

  def exhibitor_ticket_type?(ticket_type)
    name = normalize_value(ticket_type.name)
    name.include?('exhibitor') && !conference_like_name?(name)
  end

  def conference_ticket_type?(ticket_type)
    name = normalize_value(ticket_type.name)
    conference_like_name?(name) && !name.include?('exhibitor')
  end

  def combined_ticket_type?(ticket_type)
    name = normalize_value(ticket_type.name)
    name.include?('exhibitor') && conference_like_name?(name)
  end

  def combined_ticket_type
    @combined_ticket_type ||= @event.ticket_types.find { |ticket_type| combined_ticket_type?(ticket_type) }
    @combined_ticket_type ||= @event.ticket_types.create!(
      name: COMBINED_TICKET_TYPE_NAME,
      price: 0,
      quantity: TICKET_TYPE_QUANTITY,
      max_per_order: TICKET_TYPE_QUANTITY,
      status: :published,
      hidden: true
    )
  end

  def conference_like_name?(name)
    name.include?('conference') || name.include?('delegate')
  end

  def normalize_value(value)
    value.to_s.strip.downcase.gsub(/\s+/, ' ')
  end

  def normalized_slug(value)
    value.to_s.strip.downcase
  end
end
