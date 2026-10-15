# frozen_string_literal: true

# A stored AI summary of a form's comments. Generated on demand by an org_owner,
# read by anyone who can see the responses.
class FeedbackAiSummary < ApplicationRecord
  STATUSES = %w[queued running ready failed].freeze
  # A job that never reported back shouldn't block new runs forever.
  ACTIVE_WINDOW = 10.minutes
  COOLDOWN = 60.seconds
  DAILY_LIMIT = 10

  belongs_to :feedback_form
  belongs_to :ai_model, optional: true
  belongs_to :generated_by, class_name: 'User', optional: true

  validates :status, inclusion: { in: STATUSES }

  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :active, -> { where(status: %w[queued running]).where('created_at > ?', ACTIVE_WINDOW.ago) }

  def ready? = status == 'ready'

  # New responses arrived after this summary started reading comments.
  def stale?
    return false unless ready? && started_at

    FeedbackResponseScope.call(feedback_form, filters.symbolize_keys).where('submitted_at > ?', started_at).exists?
  end
end
