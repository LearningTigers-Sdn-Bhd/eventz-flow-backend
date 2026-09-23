module V1
  module Public
    class FeedbackResponsesController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create
        attributes = response_params
        form = FeedbackForm.find(attributes.fetch(:form_id))
        raise ActiveRecord::RecordNotFound unless form.is_active?

        if attributes[:ticket_id].present? && attributes[:ticket_public_id].blank?
          return error_response(
            message: 'ticket_public_id is required when ticket_id is provided',
            status: :unprocessable_content
          )
        end

        ticket = find_ticket(form, attributes)
        answers = Array(attributes[:answers]).map(&:to_h)
        questions_by_id = form.feedback_questions.index_by { |question| question.id.to_s }
        answer_ids = answers.map { |answer| answer[:question_id].to_s }

        if answer_ids.uniq.length != answer_ids.length
          return error_response(message: 'A question can only be answered once', status: :unprocessable_content)
        end

        if answer_ids.any? { |id| !questions_by_id.key?(id) }
          return error_response(message: 'One or more questions are invalid', status: :unprocessable_content)
        end

        answers_by_id = answers.index_by { |answer| answer[:question_id].to_s }
        missing_questions = form.feedback_questions.select do |question|
          answer = answers_by_id[question.id.to_s]
          question.required? && (answer.nil? || answer[:answer_text].to_s.strip.blank?)
        end

        if missing_questions.any?
          return error_response(
            message: 'Required questions must be answered',
            errors: missing_questions.map { |question| "#{question.question_text} is required" },
            status: :unprocessable_content
          )
        end

        response = nil
        FeedbackResponse.transaction do
          response = form.feedback_responses.create!(ticket:, submitted_at: Time.current)
          answers.each do |answer|
            response.feedback_answers.create!(
              feedback_question: questions_by_id.fetch(answer[:question_id].to_s),
              answer_text: answer[:answer_text]
            )
          end
        end

        success_response(
          data: FeedbackResponseSerializer.serialize(response),
          status: :created
        )
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Feedback form or ticket not found', status: :not_found)
      rescue ActiveRecord::RecordInvalid => e
        error_response(
          message: 'Feedback response is invalid',
          errors: e.record.errors.full_messages,
          status: :unprocessable_content
        )
      rescue ActiveRecord::RecordNotUnique
        error_response(message: 'Feedback has already been submitted for this ticket', status: :unprocessable_content)
      end

      private

      def response_params
        params.permit(:form_id, :ticket_id, :ticket_public_id, answers: %i[question_id answer_text]).tap do |permitted|
          permitted[:form_id] = params.require(:form_id)
        end
      end

      def find_ticket(form, attributes)
        return if attributes[:ticket_id].blank? && attributes[:ticket_public_id].blank?

        if attributes[:ticket_id].present?
          form.event.tickets.find_by!(id: attributes[:ticket_id], public_id: attributes[:ticket_public_id])
        else
          form.event.tickets.find_by!(public_id: attributes[:ticket_public_id])
        end
      end
    end
  end
end
