# frozen_string_literal: true

class BusinessMatchingSession < ApplicationRecord
  belongs_to :event
  has_many :business_matching_availabilities, dependent: :destroy
  has_many :business_matching_bookings, dependent: :destroy
  has_many :business_host_assignments, class_name: 'BusinessHostAssignment', foreign_key: :business_matching_event_id, primary_key: :id, dependent: :destroy

  before_destroy :ensure_no_bookings, prepend: true
  before_validation :default_date_range

  validates :title, presence: true
  validates :slot_duration, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_not_before_start_date

  # The single "effective" availability bucket for this session: the
  # assigned host's own (host_user_id-specific) rows if they have any,
  # otherwise the shared default (host_user_id: nil) bucket. Mirrors
  # BusinessMatchingService#fetch_availability's bucket preference exactly —
  # reads, writes, and the date-range backfill must all agree on this same
  # bucket, or a session ends up with two parallel sets of rows for the same
  # days (shown as duplicate blocks in the availability manager).
  def effective_host_user_id
    host_id = business_host_assignments.pick(:user_id)
    return nil if host_id.nil?

    business_matching_availabilities.where(host_user_id: host_id).exists? ? host_id : nil
  end

  # Whether the given host may self-edit their tags for this session: the
  # host's own override wins if set, otherwise the session's default.
  def tags_editable_for(host_user)
    assignment = business_host_assignments.find_by(user_id: host_user&.id)
    override = assignment&.tags_editable_override
    override.nil? ? tags_editable : override
  end

  # Same nil-inherits chain as tags_editable_for, but with an extra level:
  # host override > session default > the event's default.
  def hours_editable_for(host_user)
    assignment = business_host_assignments.find_by(user_id: host_user&.id)
    return assignment.hours_editable_override unless assignment&.hours_editable_override.nil?

    hours_editable.nil? ? event.business_matching_hours_editable_default : hours_editable
  end

  private

  # The session may run entirely before or after its event — these are just
  # convenience defaults for callers (specs, console, legacy integrations)
  # that don't specify a range explicitly. Prefer the event's configured BM
  # default range (e.g. "just day 3 of the event") over the event's own
  # full date range.
  def default_date_range
    self.start_date ||= event&.business_matching_default_start_date ||
                         event&.start_date&.to_date || Date.current
    self.end_date ||= event&.business_matching_default_end_date ||
                       event&.end_date&.to_date || start_date
  end

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank?

    errors.add(:end_date, "must be on or after the start date") if end_date < start_date
  end

  def ensure_no_bookings
    if business_matching_bookings.where.not(status: 'Cancelled').exists?
      errors.add(:base, "Cannot delete session with active bookings. Please cancel or remove all bookings first.")
      throw(:abort)
    end
  end
end
