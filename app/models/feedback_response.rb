class FeedbackResponse < ApplicationRecord
  belongs_to :feedback_form
  belongs_to :ticket, optional: true
  has_many :feedback_answers, dependent: :destroy

  validates :submitted_at, presence: true
  validates :ticket_id, uniqueness: { scope: :feedback_form_id, message: 'has already submitted feedback' },
                        allow_nil: true
end
