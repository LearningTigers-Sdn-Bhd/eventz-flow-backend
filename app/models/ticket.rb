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
  validates :attendee_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :attendee_phone, format: { with: /\A[+]?[\d\s\-\(\)]+\z/, message: 'must be a valid phone number' }, allow_blank: true
  validates :status, presence: true # Although redundant with enum presence check, it's clear.
  validates :payment_status, presence: true

  # --- Scopes ---
  scope :checked_in, -> { where(checked_in: true) }
  scope :active, -> { where(status: [:purchased, :scanned]) }
  scope :unscanned, -> { active.where(checked_in: false) }
  scope :within_date_range, ->(range) { where(created_at: range) }

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

  # --- Private Methods ---
  private

  def set_public_id
    # Generates a UUID only if it hasn't been set by the database or another source.
    self.public_id ||= SecureRandom.uuid
  end
end
