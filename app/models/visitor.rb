class Visitor < ApplicationRecord
  include TimeSeriesAnalytics

  # --- Callbacks ---
  # Ensure public_id is set before any presence validations run on create.
  before_validation :set_public_id, on: :create
  before_validation :normalize_attendee_fields

  # --- Associations ---
  belongs_to :event
  belongs_to :scanned_by, class_name: 'User', foreign_key: 'scanned_by_id', optional: true
  has_many :event_leads, as: :leadable, dependent: :destroy
  has_many :voucher_usages, as: :redeemer, dependent: :destroy
  has_many :voucher_redemption_logs, as: :redeemer, dependent: :destroy
  
  has_many :table_assignments, dependent: :destroy
  has_many :assigned_tables, through: :table_assignments, source: :plan_object
  has_one :event_seating_group_member, as: :participant, dependent: :destroy

  # --- RSVP Associations ---
  has_many :companions, class_name: 'Visitor', foreign_key: 'added_by_id', dependent: :destroy
  belongs_to :added_by, class_name: 'Visitor', optional: true

  # --- Enums ---
  enum :rsvp_status, { pending: 0, attending: 1, declined: 2 }

  # --- RSVP Scopes ---
  scope :primary_invitees, -> { where(added_by_id: nil) }
  scope :companions_of, ->(visitor_id) { where(added_by_id: visitor_id) }

  # --- Scopes ---
  scope :checked_in, -> { where(checked_in: true) }
  scope :unscanned, -> { where(checked_in: false) }
  scope :unassigned, -> { left_outer_joins(:table_assignments).where(table_assignments: { id: nil }) }
  scope :unassigned_in_plan, ->(plan) {
    where.not(id: joins(:table_assignments).joins(table_assignments: :plan_object).where(plan_objects: { plan_id: plan.id }).select(:id))
  }

  # --- Validations ---
  validates :event_id, presence: true
  # The original `validates :public_id, presence: true` caused issues because
  # the value wasn't set when FactoryBot tried to save.
  # We check presence only on :update, relying on the `before_validation` callback for creation.
  validates :public_id, presence: true, on: :update

  validates :full_name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A[+]?[\d\s\-\(\)]+\z/, message: 'must be a valid phone number' }, allow_blank: true

  after_commit :send_webhook_notification, on: [:create, :update]
  after_commit :create_matching_participant, on: :create

  attr_accessor :skip_webhooks

  # --- Private Methods ---
  private

  def create_matching_participant
    return unless event.use_business_matching
    BusinessMatchingParticipant.find_or_create_by!(
      event_id: event_id,
      registerable_type: self.class.name,
      registerable_id: id
    )
  end
  private

  def set_public_id
    # Generates a UUID only if it hasn't been set by the database or another source.
    self.public_id ||= SecureRandom.uuid
  end

  def normalize_attendee_fields
    # Title-case full_name for display
    self.full_name = titleize_name(full_name) if full_name.present?

    if has_attribute?(:full_name_norm)
      self.full_name_norm = normalize_name_key(full_name) if will_save_change_to_full_name? || full_name_norm.blank?
    end
    if has_attribute?(:email_norm)
      self.email_norm = normalize_email_key(email) if will_save_change_to_email? || email_norm.blank?
    end
    if has_attribute?(:phone_norm)
      self.phone_norm = normalize_phone_key(phone) if will_save_change_to_phone? || phone_norm.blank?
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

  def send_webhook_notification
    return if skip_webhooks
    return unless event.webhook_url.present?

    event_type = determine_event_type
    return if event_type.nil?

    # For updates, skip if nothing significant changed
    return if event_type == 'visitor.updated' && !significant_changes?

    payload = build_webhook_payload(event_type)
    event.webhook_urls.each do |url|
      WebhookSenderJob.perform_later(url, payload)
    end
  end

  def determine_event_type
    return 'visitor.created' if previous_changes[:id].present?
    return 'visitor.scanned' if previous_changes[:checked_in] == [false, true]
    'visitor.updated'
  end

  def build_webhook_payload(event_type)
    # For creation, send full data. For updates, send minimal data + changes
    is_creation = event_type == 'visitor.created'

    payload = {
      event_type: event_type,
      webhook_id: SecureRandom.uuid,
      timestamp: Time.now.utc.iso8601,
      api_version: "v1",

      visitor: {
        id: self.id,
        public_id: self.public_id,
        role: self.role,
        full_name: self.full_name,
        email: self.email,
        phone: self.phone,
        gender: self.gender,
        age: self.age,
        custom_fields: self.custom_fields_data
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

    # Add scanned_by information if visitor was scanned by a user
    if self.scanned_by_id.present? && self.scanned_by
      payload[:scanned_by] = {
        id: self.scanned_by.id,
        full_name: self.scanned_by.full_name,
        email: self.scanned_by.email
      }
    end

    # Add full context on creation
    if is_creation
      payload[:visitor].merge!(
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
      if event_type == 'visitor.scanned'
        payload[:visitor][:checked_in] = self.checked_in
        payload[:visitor][:check_in_at] = self.check_in_at&.iso8601
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
    significant_fields = %w[full_name email phone checked_in]
    (previous_changes.keys & significant_fields).any?
  end
end
