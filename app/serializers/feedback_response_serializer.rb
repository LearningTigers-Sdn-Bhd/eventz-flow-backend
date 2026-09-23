class FeedbackResponseSerializer
  def self.serialize(response)
    {
      id: response.id,
      feedback_form_id: response.feedback_form_id,
      ticket_id: response.ticket_id,
      submitted_at: response.submitted_at,
      answers: response.feedback_answers.map do |answer|
        {
          question_id: answer.feedback_question_id,
          answer_text: answer.answer_text
        }
      end
    }
  end
end
