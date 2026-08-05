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

  # When an admin renames a tag in the curated list, propagate the rename to
  # every participant in `scope` who had already selected the old value —
  # otherwise their selection would silently disappear from the picker.
  def self.apply_tag_renames(scope, offering_renames: [], interest_renames: [])
    offering_map = rename_map(offering_renames)
    interest_map = rename_map(interest_renames)
    return if offering_map.empty? && interest_map.empty?

    scope.find_each do |participant|
      changed = false

      if offering_map.any?
        renamed = participant.offering_tags.map { |t| offering_map[t] || t }
        if renamed != participant.offering_tags
          participant.offering_tags = renamed
          changed = true
        end
      end

      if interest_map.any?
        renamed = participant.interest_tags.map { |t| interest_map[t] || t }
        if renamed != participant.interest_tags
          participant.interest_tags = renamed
          changed = true
        end
      end

      participant.save! if changed
    end
  end

  def self.rename_map(renames)
    Array(renames).each_with_object({}) do |r, map|
      from = r[:from].to_s.strip
      to = r[:to].to_s.strip
      map[from] = to if from.present? && to.present?
    end
  end
  private_class_method :rename_map
end
