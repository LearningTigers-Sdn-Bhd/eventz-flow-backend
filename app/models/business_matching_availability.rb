# frozen_string_literal: true

class BusinessMatchingAvailability < ApplicationRecord
  belongs_to :business_matching_session
  belongs_to :host_user, class_name: 'User', optional: true
  belongs_to :business_matching_participant, optional: true

  validates :day, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
end
