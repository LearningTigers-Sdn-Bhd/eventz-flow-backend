# frozen_string_literal: true

# One written answer for the organizer's Comments tab. `response_rating` is the
# average of that response's ratings, selected by the controller's query.
class FeedbackCommentSerializer
  def self.serialize(answer)
    respondent = FeedbackRespondent.for(answer.feedback_response)
    {
      id: answer.id,
      question_id: answer.feedback_question_id,
      question_text: answer.feedback_question.question_text,
      answer_text: answer.answer_text,
      submitted_at: answer.feedback_response.submitted_at,
      response_rating: answer.attributes['response_rating']&.to_f&.round(1),
      attendee: respondent && {
        name: respondent[:attendee_name],
        email: respondent[:attendee_email],
        ticket_type_name: respondent[:ticket_type_name]
      }
    }
  end
end
