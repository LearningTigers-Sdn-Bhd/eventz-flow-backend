# frozen_string_literal: true

class FeedbackFormSerializer
  # stats: organizer-only counts used to lock risky edits on a live form.
  def self.serialize(form, stats: false)
    answer_counts = stats ? FeedbackAnswer.where(feedback_question_id: form.feedback_questions.map(&:id)).group(:feedback_question_id).count : {}

    payload = {
      id: form.id,
      event_id: form.event_id,
      updated_at: form.updated_at.utc.iso8601(6),
      title: form.title,
      description: form.description,
      is_active: form.is_active,
      display_mode: form.display_mode,
      pages_metadata: form.pages_metadata || [],
      thank_you_title: form.thank_you_title,
      thank_you_message: form.thank_you_message,
      questions: form.feedback_questions.map do |question|
        {
          id: question.id,
          question_text: question.question_text,
          question_type: question.question_type,
          options: (question.choice_type? || question.rating?) ? question.options : nil,
          required: question.required,
          position: question.position,
          placeholder: question.placeholder,
          hint_text: question.hint_text,
          page_number: question.page_number || 1,
          routing_rules: question.routing_rules || [],
          **(stats ? { answers_count: answer_counts[question.id] || 0 } : {})
        }
      end
    }
    payload[:response_count] = form.feedback_responses.count if stats
    payload
  end
end

