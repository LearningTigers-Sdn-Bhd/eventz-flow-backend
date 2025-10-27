class TicketType < ApplicationRecord
  # 🔑 This line is the fix: It creates the 'event' association and the 'event=' method.
  # Made optional to support global ticket types (templates)
  belongs_to :event, optional: true
  has_many :tickets # Assuming a future Ticket model

  # --- Callbacks ---
  after_commit :send_webhook_notification, on: [:create, :update]

  # Enums for Status
  enum :status, { draft: 0, published: 1, archived: 2 }

  # Validations
  validates :name, presence: true, length: { maximum: 100 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :quantity, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :max_per_order, presence: true, numericality: { greater_than_or_equal_to: 1 }

  # Scopes
  scope :global, -> { where(event_id: nil) }
  scope :event_specific, -> { where.not(event_id: nil) }
  scope :publicly_available, -> { published.where(hidden: false) }
  scope :on_sale, -> { 
    where('sale_starts_at IS NULL OR sale_starts_at <= ?', Time.current)
    .where('sale_ends_at IS NULL OR sale_ends_at >= ?', Time.current)
  }

  # Helper method to check if the ticket type is currently available for purchase
  def available?
    published? && !hidden? && on_sale?
  end

  def send_webhook_notification
    # Only send webhooks for event-specific ticket types (not global templates)
    return unless event.present? && event.webhook_url.present?
    
    event_type = determine_event_type
    return if event_type.nil?
    
    WebhookSenderJob.perform_later(event.webhook_url, build_webhook_payload(event_type))
  end

  private

  def on_sale?
    (sale_starts_at.nil? || sale_starts_at <= Time.current) &&
    (sale_ends_at.nil? || sale_ends_at >= Time.current)
  end

  def determine_event_type
    return 'ticket_type.created' if previous_changes[:id].present?
    return 'ticket_type.published' if previous_changes[:status] == [0, 1]
    return 'ticket_type.sold_out' if sold_out?
    return 'ticket_type.archived' if previous_changes[:status]&.last == 2
    return 'ticket_type.updated' if significant_changes?
    
    nil
  end

  def sold_out?
    tickets.count >= quantity && quantity > 0
  end

  def significant_changes?
    significant_fields = %w[name price quantity status sale_starts_at sale_ends_at]
    (previous_changes.keys & significant_fields).any?
  end

  def build_webhook_payload(event_type)
    is_creation = event_type == 'ticket_type.created'
    
    payload = {
      event_type: event_type,
      webhook_id: SecureRandom.uuid,
      timestamp: Time.now.utc.iso8601,
      api_version: "v1",
      
      ticket_type: {
        id: self.id,
        name: self.name,
        price: self.price.to_f,
        quantity: self.quantity,
        status: self.status
      },
      
      event: {
        id: event.id,
        title: event.title
      }
    }
    
    # Add full context on creation
    if is_creation
      payload[:ticket_type].merge!(
        max_per_order: self.max_per_order,
        hidden: self.hidden,
        sale_starts_at: self.sale_starts_at&.iso8601,
        sale_ends_at: self.sale_ends_at&.iso8601,
        created_at: self.created_at.iso8601
      )
    else
      # Add changes for updates
      payload[:changes] = format_changes
    end
    
    payload.compact
  end

  def format_changes
    self.previous_changes.except('updated_at').transform_values do |change|
      {
        from: change[0],
        to: change[1]
      }
    end
  end
end
