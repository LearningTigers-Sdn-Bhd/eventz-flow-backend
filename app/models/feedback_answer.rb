class FeedbackAnswer < ApplicationRecord
  RATING_RANGE = (1..5)
  YES_NO_VALUES = %w[yes no].freeze

  belongs_to :feedback_response
  belongs_to :feedback_question

  validate :answer_matches_question_type

  private

  # Blank answers are allowed here; required-ness is enforced at submission.
  # multi_choice answers are stored as a JSON array string, e.g. '["A","B"]'.
  def answer_matches_question_type
    return if answer_text.blank? || feedback_question.nil?

    valid =
      case feedback_question.question_type
      when 'rating' then answer_text.match?(/\A\d+\z/) && RATING_RANGE.cover?(answer_text.to_i)
      when 'yes_no' then YES_NO_VALUES.include?(answer_text)
      when 'single_choice' then Array(feedback_question.options).include?(answer_text)
      when 'multi_choice' then valid_multi_choice?
      else true
      end

    errors.add(:answer_text, "is not valid for \"#{feedback_question.question_text}\"") unless valid
  end

  def valid_multi_choice?
    selected = JSON.parse(answer_text)
    selected.is_a?(Array) && selected.any? && (selected - Array(feedback_question.options)).empty?
  rescue JSON::ParserError
    false
  end
end
