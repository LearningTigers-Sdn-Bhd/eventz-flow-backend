# frozen_string_literal: true

class FeedbackForm < ApplicationRecord
  belongs_to :event
  has_many :feedback_responses, dependent: :destroy
  has_many :feedback_questions, -> { order(:page_number, :position) }, dependent: :destroy

  enum :display_mode, {
    pages: 0,
    continuous: 1
  }, default: :pages, validate: true

  validates :title, presence: true
  validates :event_id, uniqueness: true
  validate :validate_pages_metadata

  private

  def validate_pages_metadata
    return if pages_metadata.blank?

    unless pages_metadata.is_a?(Array)
      errors.add(:pages_metadata, 'must be an array of page configurations')
    end
  end
end
