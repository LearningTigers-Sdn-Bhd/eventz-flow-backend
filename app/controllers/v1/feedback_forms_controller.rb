module V1
  class FeedbackFormsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :authorize_event

    # No form yet is a normal state for the builder, so it returns 200 without data.
    def show
      form = @event.feedback_form
      success_response(data: form && FeedbackFormSerializer.serialize(form))
    end

    def create
      save_feedback_form(FeedbackForm.new(event: @event), :created)
    end

    def update
      form = @event.feedback_form
      raise ActiveRecord::RecordNotFound unless form

      save_feedback_form(form, :ok)
    end

    # Multi-choice answers are stored as JSON arrays; strip brackets/quotes so
    # a search for `"` or `[` doesn't match every multi-choice response.
    SEARCHABLE_ANSWER_SQL = <<~SQL.squish.freeze
      CASE WHEN feedback_answers.answer_text LIKE '[%'
      THEN REGEXP_REPLACE(feedback_answers.answer_text, '[\\[\\]"]', '', 'g')
      ELSE feedback_answers.answer_text END
    SQL

    def summary
      form = @event.feedback_form
      return success_response unless form

      success_response(data: FeedbackFormSummary.call(form))
    end

    def responses
      form = @event.feedback_form
      scope = form ? form.feedback_responses : FeedbackResponse.none
      if params[:ticket_type_id].present?
        scope = scope.where(
          ticket_id: Ticket.where(ticket_type_id: params[:ticket_type_id]).select(:id)
        )
      end

      if params[:q].present?
        query = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        scope = scope.left_joins({ ticket: :ticket_type }, :feedback_answers)
                     .where(
                       "tickets.attendee_name ILIKE :query OR tickets.attendee_email ILIKE :query OR tickets.public_id::text ILIKE :query " \
                       "OR ticket_types.name ILIKE :query OR #{SEARCHABLE_ANSWER_SQL} ILIKE :query",
                       query: query
                     )
                     .distinct
      end

      scope = scope.includes(ticket: :ticket_type, feedback_answers: :feedback_question)
                   .order(submitted_at: :desc, id: :desc)
      pagy, records = pagy(scope, limit: pagination_params[:per_page] || 25)

      render json: {
        data: records.map { |record| FeedbackOrganizerResponseSerializer.serialize(record) },
        pagination: pagy_metadata(pagy)
      }, status: :ok
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def authorize_event
      authorize @event, :update?
    end

    def save_feedback_form(form, status)
      payload = params.require(:feedback_form)
      attributes = payload.permit(
        :title,
        :description,
        :is_active,
        feedback_questions_attributes: [
          :id,
          :question_text,
          :question_type,
          :required,
          :position,
          { options: [] }
        ]
      )
      question_set_provided = payload.key?(:feedback_questions_attributes)
      question_attributes = attributes.delete(:feedback_questions_attributes)

      FeedbackForm.transaction do
        form.assign_attributes(attributes)
        form.save!
        replace_questions!(form, question_attributes || []) if question_set_provided
      end

      success_response(data: FeedbackFormSerializer.serialize(form.reload), status: status)
    rescue ActiveRecord::RecordInvalid => e
      error_response(
        message: 'Feedback form is invalid',
        errors: e.record.errors.full_messages,
        status: :unprocessable_content
      )
    rescue ActiveRecord::RecordNotDestroyed => e
      error_response(
        message: 'Feedback form is invalid',
        errors: e.record.errors.full_messages,
        status: :unprocessable_content
      )
    end

    def replace_questions!(form, attributes)
      rows = attributes.is_a?(Array) ? attributes : attributes.to_h.values
      ids = rows.filter_map { |row| row[:id].presence }.map(&:to_i)

      questions_to_remove = ids.empty? ? form.feedback_questions.to_a : form.feedback_questions.where.not(id: ids)
      questions_to_remove.each(&:destroy!)

      rows.each do |row|
        question_attributes = row.to_h.symbolize_keys
        id = question_attributes.delete(:id)
        question = id.present? ? form.feedback_questions.find(id) : form.feedback_questions.build
        question.assign_attributes(question_attributes)
        question.options = nil unless question.choice_type?
        question.save!
      end
    end
  end
end
