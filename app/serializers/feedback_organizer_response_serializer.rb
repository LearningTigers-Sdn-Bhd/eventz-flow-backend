class FeedbackOrganizerResponseSerializer
  def self.serialize(response)
    {
      id: response.id,
      submitted_at: response.submitted_at,
      ticket: serialize_ticket(response.ticket),
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

  def self.serialize_ticket(ticket)
    return unless ticket

    {
      public_id: ticket.public_id,
      attendee_name: ticket.attendee_name,
      attendee_email: ticket.attendee_email,
      ticket_type_name: ticket.ticket_type&.name
    }
  end
  private_class_method :serialize_ticket
end
