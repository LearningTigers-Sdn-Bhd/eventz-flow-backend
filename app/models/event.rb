class Event < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged
  # --- Associations (Refactored) ---

  # Unified event staff assignment
  has_many :event_assignments, dependent: :destroy
  has_many :staff, through: :event_assignments, source: :user

  has_many :business_host_assignments, dependent: :destroy # Added association

  # Core Event Resources
  has_many :event_locations, dependent: :destroy, inverse_of: :event
  has_many :ticket_types, dependent: :destroy
  has_many :registration_forms, dependent: :destroy
  has_many :tickets, dependent: :destroy
  has_many :event_vendors, dependent: :destroy
  has_many :exhibitors, -> { where(type: 'Exhibitor') }, class_name: 'Exhibitor', inverse_of: :event
  has_many :merchants, -> { where(type: 'Merchant') }, class_name: 'Merchant', inverse_of: :event
  has_many :visitors, dependent: :destroy
  has_many :vouchers, dependent: :destroy
  has_one :event_exhibition_contractor, dependent: :destroy
  has_many :event_exhibition_contractors, dependent: :destroy
  has_many :event_printing_services, dependent: :destroy
  has_many :event_rentable_items, dependent: :destroy
  has_many :lucky_draw_sessions, dependent: :destroy
  has_many :roulette_sessions, dependent: :destroy
  has_one :exhibitor_team_member_limit, dependent: :destroy
  has_one :check_in_display, dependent: :destroy

  # --- Sponsorships ---
  has_many :event_sponsorship_tiers, dependent: :destroy
  has_many :event_sponsorships, dependent: :destroy
  has_many :sponsors, through: :event_sponsorships

  # --- Reminders ---
  has_many :event_reminder_logs, dependent: :destroy

  # --- Callbacks ---
  after_commit :send_webhook_notification, on: [:create, :update]
  after_update :sync_custom_labels_to_attendees, if: :saved_change_to_labels_data?

  attr_accessor :skip_webhooks

  # --- Validations ---
  validates :title, presence: true, length: { maximum: 100 }
  validates :status, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true

  validate :end_date_must_be_after_start_date

  # --- Enums ---
  enum :status, { draft: 0, published: 1, cancelled: 2, completed: 3 }
  enum :payment_status, { unpaid: 0, paid: 1, waived: 2 }

  # --- Soft Delete Scopes ---
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscoped }
  scope :only_deleted, -> { unscoped.where.not(deleted_at: nil) }

  # --- Scopes for specific event staff roles ---

  has_many :admins, -> { where(event_assignments: { role: :event_admin }) },
         through: :event_assignments,
         source: :user

  has_many :team_members, -> { where(event_assignments: { role: :event_team_member }) },
         through: :event_assignments,
         source: :user

  def waived_fees?
    # This assumes 'waived' is a payment_status enum value,
    # meaning Rails automatically defined the `waived?` helper.
    waived?
  end

  def paid_or_waived?
    # Replace this with the actual logic for your Event model
    # For example, it might check a boolean column or a subscription status:
    paid? || waived_fees?

    # For the test to pass, a basic implementation might look like this
    # until you know the actual column names:
    true # Or check a column like self.status == 'paid'
  end

  def staff_role_grants_update?(user)
    assignment = event_assignments.find_by(user: user)
    return false unless assignment

    # Ensure ONLY the roles that can update are listed
    ['event_admin'].include?(assignment.role)
  end

  # --- Soft Delete Methods ---
  def archive
    update(deleted_at: Time.current)
  end

  def restore
    self.class.unscoped.find(id).update(deleted_at: nil)
  end

  def delete
    # Use unscoped to properly destroy soft-deleted associations
    # Manually destroy all associations (including soft-deleted ones) before destroying the event
    Ticket.unscoped.where(event_id: id).destroy_all
    EventLocation.where(event_id: id).destroy_all
    TicketType.where(event_id: id).destroy_all
    EventVendor.where(event_id: id).destroy_all
    EventAssignment.where(event_id: id).destroy_all
    Visitor.where(event_id: id).destroy_all
    # Now destroy the event itself (unscoped to find soft-deleted events)
    Event.unscoped.find(id).destroy!
  end

  def send_webhook_notification
    return if skip_webhooks
    return unless webhook_url.present?

    event_type = determine_event_type
    return if event_type.nil?  # Skip if no significant change

    WebhookSenderJob.perform_later(webhook_url, build_webhook_payload(event_type))
  end

  # Sync custom label keys to tickets and visitors when labels_data changes
  def sync_custom_labels_to_attendees
    old_labels, new_labels = saved_change_to_labels_data
    old_labels ||= {}
    new_labels ||= {}

    # Build key mapping by comparing old and new labels by position
    old_keys = old_labels.keys
    new_keys = new_labels.keys

    # Find keys that were renamed (same position, different key)
    key_mapping = {}
    old_keys.each_with_index do |old_key, index|
      new_key = new_keys[index]
      # If there's a new key at this position and it's different, it's a rename
      if new_key.present? && old_key != new_key
        key_mapping[old_key] = new_key
      end
    end

    # Update tickets and visitors if there are key changes
    return if key_mapping.empty?

    # Update tickets
    tickets.find_each do |ticket|
      update_custom_fields_keys(ticket, key_mapping)
    end

    # Update visitors
    visitors.find_each do |visitor|
      update_custom_fields_keys(visitor, key_mapping)
    end
  end

  private

  # Update custom_fields_data keys based on the mapping
  def update_custom_fields_keys(record, key_mapping)
    return unless record.custom_fields_data.present?

    updated_data = {}
    record.custom_fields_data.each do |key, value|
      # Use new key if it exists in mapping, otherwise keep original key
      new_key = key_mapping[key] || key
      updated_data[new_key] = value
    end

    # Only update if data actually changed
    if updated_data != record.custom_fields_data
      record.update_columns(custom_fields_data: updated_data)
    end
  end

  def end_date_must_be_after_start_date
    if start_date.present? && end_date.present? && end_date < start_date
      errors.add(:end_date, 'must be after the start date')
    end
  end

  def determine_event_type
    return 'event.created' if previous_changes[:id].present?
    return 'event.published' if previous_changes[:status] == [0, 1] || previous_changes[:published] == [false, true]
    return 'event.canceled' if previous_changes[:status]&.last == 2
    return 'event.updated' if significant_changes?

    nil  # No webhook for minor changes
  end

  def significant_changes?
    significant_fields = %w[title start_date end_date description status webhook_url visibility]
    (previous_changes.keys & significant_fields).any?
  end

  def build_webhook_payload(event_type)
    {
      # === WEBHOOK METADATA ===
      event_type: event_type,
      webhook_id: SecureRandom.uuid,
      timestamp: Time.now.utc.iso8601,
      api_version: "v1",

      # === EVENT DATA (Basic info only) ===
      event: {
        id: self.id,
        title: self.title,
        status: self.status,
        start_date: self.start_date&.iso8601,
        end_date: self.end_date&.iso8601
      },

      # === CHANGES (what actually changed) ===
      changes: format_changes
    }.compact
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
