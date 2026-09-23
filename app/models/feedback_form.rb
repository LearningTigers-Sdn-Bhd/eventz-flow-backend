class FeedbackForm < ApplicationRecord
  belongs_to :event
  has_many :feedback_responses, dependent: :destroy
  has_many :feedback_questions, -> { order(:position) }, dependent: :destroy

  validates :title, presence: true
  validates :event_id, uniqueness: true
end
