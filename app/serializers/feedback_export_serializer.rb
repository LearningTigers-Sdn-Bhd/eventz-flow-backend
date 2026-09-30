# frozen_string_literal: true

# The pieces of the export payload the panel turns into CSV, Excel and PDF files.
class FeedbackExportSerializer
  def self.question(question)
    {
      id: question.id,
      question_text: question.question_text,
      question_type: question.question_type,
      options: (question.choice_type? || question.rating?) ? question.options : nil,
      required: question.required,
      page_number: question.page_number,
      position: question.position,
      routing_rules: question.routing_rules || []
    }
  end

  def self.response(response)
    ticket = response.ticket
    {
      id: response.id,
      submitted_at: response.submitted_at,
      ticket: ticket && {
        public_id: ticket.public_id,
        attendee_name: ticket.attendee_name,
        attendee_email: ticket.attendee_email,
        ticket_type_name: ticket.ticket_type&.name
      },
      # multi_choice comes back as an array, everything else as the stored text
      answers: response.feedback_answers.to_h { |answer| [answer.feedback_question_id, answer_value(answer)] }
    }
  end

  def self.comments(responses)
    responses.flat_map do |response|
      response.feedback_answers.select { |a| a.feedback_question&.text? && a.answer_text.to_s.strip.present? }.map do |a|
        {
          question_id: a.feedback_question_id,
          question_text: a.feedback_question.question_text,
          answer_text: a.answer_text,
          submitted_at: response.submitted_at,
          attendee_name: response.ticket&.attendee_name,
          attendee_email: response.ticket&.attendee_email
        }
      end
    end
  end

  def self.answer_value(answer)
    return answer.answer_text unless answer.feedback_question&.multi_choice?

    Array(JSON.parse(answer.answer_text))
  rescue JSON::ParserError
    answer.answer_text
  end
  private_class_method :answer_value
end
