# frozen_string_literal: true

class BusinessMatchingParticipant < ApplicationRecord
  belongs_to :event
  belongs_to :registerable, polymorphic: true

  has_many :availabilities, class_name: 'BusinessMatchingAvailability', foreign_key: :business_matching_participant_id, dependent: :destroy
  has_many :sent_bookings, class_name: 'BusinessMatchingBooking', foreign_key: :requester_participant_id, dependent: :destroy
  has_many :received_bookings, class_name: 'BusinessMatchingBooking', foreign_key: :receiver_participant_id, dependent: :destroy

  has_secure_token :magic_token

  validates :event, presence: true
  validates :registerable, presence: true

  # Tag helpers for profile matching
  def offering_tags
    profile_data['offering_tags'] || []
  end

  def offering_tags=(tags)
    self.profile_data ||= {}
    self.profile_data['offering_tags'] = Array(tags).map(&:to_s).map(&:strip).reject(&:empty?)
  end

  def interest_tags
    profile_data['interest_tags'] || []
  end

  def interest_tags=(tags)
    self.profile_data ||= {}
    self.profile_data['interest_tags'] = Array(tags).map(&:to_s).map(&:strip).reject(&:empty?)
  end
end
