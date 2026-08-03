# frozen_string_literal: true

class BusinessMatchingSession < ApplicationRecord
  belongs_to :event
  has_many :business_matching_availabilities, dependent: :destroy
  has_many :business_matching_bookings, dependent: :destroy
  has_many :business_host_assignments, class_name: 'BusinessHostAssignment', foreign_key: :business_matching_event_id, primary_key: :id, dependent: :destroy

  before_destroy :ensure_no_bookings, prepend: true

  validates :title, presence: true
  validates :slot_duration, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :start_time, presence: true
  validates :end_time, presence: true

  private

  def ensure_no_bookings
    if business_matching_bookings.any?
      errors.add(:base, "Cannot delete session with active bookings. Please cancel or remove all bookings first.")
      throw(:abort)
    end
  end
end
