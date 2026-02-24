class Ticket < ApplicationRecord
  include TimeSeriesAnalytics

  # --- Callbacks ---
  # Ensure public_id is set before any presence validations run on create.
  before_validation :set_public_id, on: :create
  before_validation :normalize_attendee_fields

  # --- Associations ---
  # In modern Rails, belongs_to implies presence validation by default.
  # We'll use explicit ID validation below for clarity/troubleshooting consistency.
  belongs_to :event
  belongs_to :ticket_type
  belongs_to :user, optional: true
  # belongs_to :order, optional: true
  belongs_to :scanned_by, class_name: 'User', foreign_key: 'scanned_by_id', optional: true
  has_one :ticket_payment, dependent: :destroy
  has_many :voucher_usages, as: :redeemer, dependent: :destroy
  has_many :voucher_redemption_logs, as: :redeemer, dependent: :destroy

  # --- Enums ---
  enum :status, { purchased: 0, scanned: 1, refunded: 2, canceled: 3, pending_payment: 4 }
  enum :payment_status, { pending: 0, paid: 1, failed: 2, refunded_payment: 3 }

  # --- Soft Delete Scopes ---
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscoped }
  scope :only_deleted, -> { unscoped.where.not(deleted_at: nil) }

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
  after_commit :send_confirmation_email, if: :should_send_confirmation?

  attr_accessor :skip_webhooks

  # --- Class Methods ---
  def self.total_revenue_cents
    joins(:ticket_type).sum("(ticket_types.price * 100.0)")
  end

  def send_webhook_notification
    return if skip_webhooks
    webhook_url = event.webhook_url
    return unless webhook_url.present?

    event_type = determine_event_type
    return if event_type.nil?

    # For updates, skip if nothing significant changed
    return if event_type == 'ticket.updated' && !significant_changes?

    WebhookSenderJob.perform_later(webhook_url, build_webhook_payload(event_type))
  end

  # --- Soft Delete Methods ---
  def archive
    update(deleted_at: Time.current)
  end

  def restore
    self.class.unscoped.find(id).update(deleted_at: nil)
  end

  def delete
    # Use unscoped to properly destroy soft-deleted record
    Ticket.unscoped do
      Ticket.unscoped.find(id).destroy!
    end
  end

  # --- Private Methods ---
  private

  def set_public_id
    # Generates a UUID only if it hasn't been set by the database or another source.
    self.public_id ||= SecureRandom.uuid
  end

  def normalize_attendee_fields
    # Title-case attendee_name for display while keeping a normalized key for dedupe/indexes
    self.attendee_name = titleize_name(attendee_name) if attendee_name.present?

    if has_attribute?(:attendee_name_norm)
      self.attendee_name_norm = normalize_name_key(attendee_name) if will_save_change_to_attendee_name? || attendee_name_norm.blank?
    end
    if has_attribute?(:attendee_email_norm)
      self.attendee_email_norm = normalize_email_key(attendee_email) if will_save_change_to_attendee_email? || attendee_email_norm.blank?
    end
    if has_attribute?(:attendee_phone_norm)
      self.attendee_phone_norm = normalize_phone_key(attendee_phone) if will_save_change_to_attendee_phone? || attendee_phone_norm.blank?
    end
  end

  def titleize_name(value)
    value.to_s.strip.split(/\s+/).map { |w| w.downcase.capitalize }.join(' ')
  end

  def normalize_name_key(value)
    key = value.to_s.strip.gsub(/\s+/, ' ').downcase
    key.presence
  end

  def normalize_email_key(value)
    key = value.to_s.strip.downcase
    key.presence
  end

  def normalize_phone_key(value)
    digits = value.to_s.gsub(/\D+/, '')
    digits.presence
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
        role: self.role,
        status: self.status,
        payment_status: self.payment_status,
        attendee_name: self.attendee_name,
        attendee_email: self.attendee_email,
        attendee_phone: self.attendee_phone,
        custom_fields: self.custom_fields_data
      },

      ticket_type: {
        id: self.ticket_type.id,
        name: self.ticket_type.name,
        price: self.ticket_type.price.to_f
      },

      event: {
        id: self.event.id,
        title: self.event.title
      }
    }

    # Include check_in_url if provided (from Thread local storage set in controller)
    if Thread.current[:check_in_url].present?
      payload[:check_in_url] = Thread.current[:check_in_url]
    end

    # Add scanned_by information if ticket was scanned by a user
    if self.scanned_by_id.present? && self.scanned_by
      payload[:scanned_by] = {
        id: self.scanned_by.id,
        full_name: self.scanned_by.full_name,
        email: self.scanned_by.email
      }
    end

    # Add full context on creation
    if is_creation
      payload[:ticket].merge!(
        checked_in: self.checked_in,
        check_in_at: self.check_in_at&.iso8601,
        created_at: self.created_at.iso8601
      )

      payload[:event].merge!(
        start_date: self.event.start_date&.iso8601,
        end_date: self.event.end_date&.iso8601,
        custom_labels: self.event.labels_data
      )
    else
      # Add changes for updates
      payload[:changes] = format_changes

      # Include check_in_at for scanned events
      if event_type == 'ticket.scanned'
        payload[:ticket][:checked_in] = self.checked_in
        payload[:ticket][:check_in_at] = self.check_in_at&.iso8601
      end
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

  def significant_changes?
    significant_fields = %w[status payment_status attendee_name attendee_email attendee_phone checked_in]
    (previous_changes.keys & significant_fields).any?
  end

  def should_send_confirmation?
    return false if attendee_email.blank?

    # Free ticket - send on create
    if ticket_type&.current_price&.zero?
      return previously_new_record?
    end

    # Paid ticket - send when payment confirmed
    saved_change_to_payment_status? && payment_status == "paid"
  end

  def send_confirmation_email
    TicketMailer.confirmation_email(self).deliver_later
  end
end
