# frozen_string_literal: true

class FeedbackFormSerializer
  def self.serialize(form)
    {
      id: form.id,
      event_id: form.event_id,
      title: form.title,
      description: form.description,
      is_active: form.is_active,
      display_mode: form.display_mode,
      pages_metadata: form.pages_metadata || [],
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
          routing_rules: question.routing_rules || []
        }
      end
    }
  end
end

