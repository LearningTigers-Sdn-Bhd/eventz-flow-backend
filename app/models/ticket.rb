class Ticket < ApplicationRecord
  # --- Callbacks ---
  # Ensure public_id is set before any presence validations run on create.
  before_validation :set_public_id, on: :create

  # --- Associations ---
  # In modern Rails, belongs_to implies presence validation by default.
  # We'll use explicit ID validation below for clarity/troubleshooting consistency.
  belongs_to :event
  belongs_to :ticket_type
  belongs_to :user, optional: true
  # belongs_to :order, optional: true
  belongs_to :scanned_by, class_name: 'User', foreign_key: 'scanned_by_id', optional: true

  # --- Enums ---
  enum :status, { purchased: 0, scanned: 1, refunded: 2, canceled: 3 }
  enum :payment_status, { pending: 0, paid: 1, failed: 2, refunded_payment: 3 }

  # --- Validations ---

  # Explicitly validate foreign keys for clear error messages.
  validates :event_id, presence: true
  validates :ticket_type_id, presence: true

  # The original `validates :public_id, presence: true` caused issues because
  # the value wasn't set when FactoryBot tried to save.
  # We check presence only on :update, relying on the `before_validation` callback for creation.
  validates :public_id, presence: true, on: :update

  validates :attendee_name, presence: true
  validates :attendee_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :attendee_phone, format: { with: /\A[+]?[\d\s\-\(\)]+\z/, message: 'must be a valid phone number' }, allow_blank: true
  validates :status, presence: true # Although redundant with enum presence check, it's clear.
  validates :payment_status, presence: true

  # --- Scopes ---
  scope :checked_in, -> { where(checked_in: true) }
  scope :active, -> { where(status: [:purchased, :scanned]) }
  scope :unscanned, -> { active.where(checked_in: false) }
  scope :within_date_range, ->(range) { where(created_at: range) }

  after_commit :send_webhook_notification, on: [:create, :update]

  # --- Class Methods ---
  def self.total_revenue_cents
    joins(:ticket_type).sum("(ticket_types.price * 100.0)")
  end

  def self.weekly_series(timestamp_column, range)
    grouped = where(timestamp_column => range)
      .group(Arel.sql("DATE(#{ActiveRecord::Base.connection.quote_column_name(timestamp_column.to_s)})"))
      .count

    range.to_a.map do |date|
      { date: date.to_s, count: grouped.fetch(date, 0) }
    end
  end

  def self.weekly_revenue_series(range)
    grouped = joins(:ticket_type)
      .where(created_at: range)
      .group(Arel.sql("DATE(tickets.created_at)"))
      .sum("(ticket_types.price * 100.0)")

    range.to_a.map do |date|
      { date: date.to_s, count: grouped.fetch(date, 0).to_i }
    end
  end

  def send_webhook_notification
    webhook_url = event.webhook_url
    return unless webhook_url.present?

    event_type = determine_event_type
    return if event_type.nil?  # Skip if no significant change

    WebhookSenderJob.perform_later(webhook_url, build_webhook_payload(event_type))
  end

  # --- Private Methods ---
  private

  def set_public_id
    # Generates a UUID only if it hasn't been set by the database or another source.
    self.public_id ||= SecureRandom.uuid
  end

  def determine_event_type
    return 'ticket.created' if previous_changes[:id].present?
    
    # Specific update events
    return 'ticket.scanned' if previous_changes[:checked_in] == [false, true]
    return 'ticket.refunded' if previous_changes[:status]&.last == 2  # refunded enum value
    return 'ticket.canceled' if previous_changes[:status]&.last == 3  # canceled enum value
    return 'ticket.payment_confirmed' if previous_changes[:payment_status] == [0, 1]  # pending to paid
    
    'ticket.updated'
  end

  def build_webhook_payload(event_type)
    # For creation, send full data. For updates, send minimal data + changes
    is_creation = event_type == 'ticket.created'
    
    payload = {
      event_type: event_type,
      webhook_id: SecureRandom.uuid,
      timestamp: Time.now.utc.iso8601,
      api_version: "v1",
      
      ticket: {
        id: self.id,
        public_id: self.public_id,
        status: self.status,
        payment_status: self.payment_status,
        attendee_name: self.attendee_name,
        attendee_email: self.attendee_email,
        attendee_phone: self.attendee_phone
      },
      
      event: {
        id: self.event.id,
        title: self.event.title
      }
    }
    
    # Add full context on creation
    if is_creation
      payload[:ticket].merge!(
        checked_in: self.checked_in,
        payment_method: self.payment_method,
        transaction_id: self.transaction_id,
        custom_fields: self.custom_fields_data,
        created_at: self.created_at.iso8601
      )
      
      payload[:ticket_type] = {
        id: self.ticket_type.id,
        name: self.ticket_type.name,
        price: self.ticket_type.price.to_f
      }
      
      payload[:event].merge!(
        start_date: self.event.start_date&.iso8601,
        end_date: self.event.end_date&.iso8601
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
