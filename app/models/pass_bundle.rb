class PassBundle < ApplicationRecord
  belongs_to :event
  belongs_to :registration_form
  belongs_to :ticket_type
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :plan_object, optional: true
  has_many :tickets, dependent: :nullify

  enum :payment_mode, { free: 0, pay_offline: 1 }
  enum :payment_status, { not_required: 0, unpaid: 1, paid: 2, sponsored: 3 }
  enum :status, { active: 0, paused: 1 }

  before_validation :set_token, on: :create
  before_validation :set_default_payment_status

  validates :name, presence: true
  validates :token, presence: true, uniqueness: { scope: :event_id }
  validates :pass_limit, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :registration_form_belongs_to_event
  validate :ticket_type_belongs_to_event
  validate :pass_limit_not_below_used_count
  validate :plan_object_must_be_table

  def used_count
    tickets.count
  end

  def remaining_count
    [pass_limit - used_count, 0].max
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def full?
    used_count >= pass_limit
  end

  def accepting_registrations?
    active? && !expired? && !full?
  end

  private

  def set_token
    self.token ||= SecureRandom.urlsafe_base64(12).tr('_-', '').downcase
  end

  def set_default_payment_status
    if free?
      self.payment_status = :not_required if payment_status.blank?
      return
    end

    return unless pay_offline?

    self.payment_status = :unpaid if payment_status.blank? || payment_status == 'not_required'
  end

  def registration_form_belongs_to_event
    return if event_id.blank? || registration_form.blank?
    return if registration_form.event_id == event_id

    errors.add(:registration_form, 'must belong to the same event')
  end

  def ticket_type_belongs_to_event
    return if event_id.blank? || ticket_type.blank?
    return if ticket_type.event_id == event_id

    errors.add(:ticket_type, 'must belong to the same event')
  end

  def pass_limit_not_below_used_count
    return if pass_limit.blank?
    return if pass_limit >= used_count

    errors.add(:pass_limit, 'cannot be lower than used passes')
  end

  def plan_object_must_be_table
    return if plan_object.blank?
    return if plan_object.object_type_table?

    errors.add(:plan_object, 'must be a table')
  end
end
