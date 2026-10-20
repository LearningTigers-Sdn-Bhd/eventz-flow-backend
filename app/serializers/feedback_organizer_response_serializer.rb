class FeedbackOrganizerResponseSerializer
  def self.serialize(response)
    {
      id: response.id,
      submitted_at: response.submitted_at,
      ticket: FeedbackRespondent.for(response),
      answers: response.feedback_answers.to_h do |answer|
        answer_text = answer.answer_text
        if answer.feedback_question&.multi_choice?
          answer_text = JSON.parse(answer_text).join(', ')
        end
        [answer.feedback_question_id, answer_text]
      rescue JSON::ParserError
        [answer.feedback_question_id, answer.answer_text]
      end
    }
  end
end
