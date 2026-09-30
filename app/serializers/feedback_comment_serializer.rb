# frozen_string_literal: true

# One written answer for the organizer's Comments tab. `response_rating` is the
# average of that response's ratings, selected by the controller's query.
class FeedbackCommentSerializer
  def self.serialize(answer)
    ticket = answer.feedback_response.ticket
    {
      id: answer.id,
      question_id: answer.feedback_question_id,
      question_text: answer.feedback_question.question_text,
      answer_text: answer.answer_text,
      submitted_at: answer.feedback_response.submitted_at,
      response_rating: answer.attributes['response_rating']&.to_f&.round(1),
      attendee: ticket && {
        name: ticket.attendee_name,
        email: ticket.attendee_email,
        ticket_type_name: ticket.ticket_type&.name
      }
    }
  end
end
