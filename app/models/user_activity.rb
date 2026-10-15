# frozen_string_literal: true

class UserActivity < ApplicationRecord
  belongs_to :user

  validates :action_name, presence: true
  validates :http_method, presence: true
  validates :path, presence: true

  scope :recent, -> { order('user_activities.created_at DESC') }
  scope :within_days, ->(days = 3) { where('user_activities.created_at >= ?', days.to_i.days.ago) }
  scope :for_category, ->(category) { where(category: category) if category.present? }
  scope :for_user, ->(user_id) { where(user_id: user_id) if user_id.present? }

  # Purge logs older than 90 days
  def self.cleanup_old_activities!(days = 90)
    where('created_at < ?', days.days.ago).delete_all
  end
end
