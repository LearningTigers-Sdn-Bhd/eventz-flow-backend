class FeedbackFormSerializer
  def self.serialize(form)
    {
      id: form.id,
      event_id: form.event_id,
      title: form.title,
      description: form.description,
      is_active: form.is_active,
      questions: form.feedback_questions.map do |question|
        {
          id: question.id,
          question_text: question.question_text,
          question_type: question.question_type,
          options: question.choice_type? ? Array(question.options) : nil,
          required: question.required,
          position: question.position
        }
      end
    }
  end
end
