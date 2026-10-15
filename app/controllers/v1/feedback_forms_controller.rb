# frozen_string_literal: true

module V1
  class FeedbackFormsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :authorize_event

    # No form yet is a normal state for the builder, so it returns 200 without data.
    def show
      form = @event.feedback_form
      success_response(data: form && FeedbackFormSerializer.serialize(form, stats: true))
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

      filters = params.permit(:ticket_type_id, :from, :to).to_h.symbolize_keys
      success_response(data: FeedbackFormSummary.call(form, filters))
    rescue FeedbackResponseScope::InvalidFilter => e
      error_response(message: e.message, status: :unprocessable_content)
    end

    def responses
      form = @event.feedback_form
      filters = params.permit(:ticket_type_id, :from, :to).to_h.symbolize_keys
      scope = form ? FeedbackResponseScope.call(form, filters) : FeedbackResponse.none
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
    rescue FeedbackResponseScope::InvalidFilter => e
      error_response(message: e.message, status: :unprocessable_content)
    end

    class StaleFormError < StandardError; end
    class LiveEditError < StandardError; end

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
        :expected_updated_at,
        :title,
        :description,
        :is_active,
        :display_mode,
        :thank_you_title,
        :thank_you_message,
        pages_metadata: [:page_number, :title, :description],
        feedback_questions_attributes: [
          :id,
          :question_text,
          :question_type,
          :required,
          :position,
          :placeholder,
          :hint_text,
          :page_number,
          { options: [] },
          { routing_rules: [:answer, :action, :target_page] }
        ]
      )
      question_set_provided = payload.key?(:feedback_questions_attributes)
      question_attributes = attributes.delete(:feedback_questions_attributes)
      expected_updated_at = attributes.delete(:expected_updated_at)

      FeedbackForm.transaction do
        if form.persisted?
          form.lock!
          # Someone else saved since this editor loaded the form.
          if expected_updated_at.present? && form.updated_at.utc.iso8601(6) != expected_updated_at
            raise StaleFormError
          end
        end
        form.assign_attributes(attributes)
        if form.pages_metadata.is_a?(Array)
          form.pages_metadata = form.pages_metadata.map do |meta|
            h = meta.to_h.stringify_keys
            h['page_number'] = h['page_number'].to_i if h['page_number'].present?
            h
          end
        end
        form.save!
        replace_questions!(form, question_attributes || []) if question_set_provided
        form.touch # bump updated_at even when only questions changed
      end

      success_response(data: FeedbackFormSerializer.serialize(form.reload, stats: true), status: status)
    rescue StaleFormError
      render json: {
        success: false,
        message: 'This form was changed by someone else since you opened it.',
        data: FeedbackFormSerializer.serialize(form.reload, stats: true)
      }, status: :conflict
    rescue LiveEditError => e
      error_response(message: e.message, status: :unprocessable_content)
    rescue ActiveRecord::RecordNotDestroyed
      error_response(
        message: "Questions that already have responses can't be deleted. Restore the question and save again.",
        status: :unprocessable_content
      )
    rescue ActiveRecord::RecordInvalid => e
      error_response(
        message: 'Feedback form is invalid',
        errors: e.record.errors.full_messages,
        status: :unprocessable_content
      )
    end

    # Once a question has responses, changing its type or removing/renaming an
    # option that people already picked would leave those answers meaningless.
    def guard_live_edit!(question, attributes)
      return unless question.feedback_answers.exists?

      new_type = attributes[:question_type].to_s
      if new_type.present? && new_type != question.question_type
        raise LiveEditError, "\"#{question.question_text}\" already has responses, so its answer type can't be changed."
      end
      return unless question.choice_type?

      used = question.feedback_answers.pluck(:answer_text).flat_map { |text| selected_options(question, text) }.uniq
      lost = used - Array(attributes[:options])
      return if lost.empty?

      raise LiveEditError,
            "\"#{lost.first}\" in \"#{question.question_text}\" was already chosen in responses and can't be removed or renamed."
    end

    def selected_options(question, text)
      return [text] unless question.multi_choice?

      Array(JSON.parse(text))
    rescue JSON::ParserError
      []
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
        guard_live_edit!(question, question_attributes) if question.persisted?
        question.assign_attributes(question_attributes)
        if question.routing_rules.is_a?(Array)
          question.routing_rules = question.routing_rules.map do |rule|
            r = rule.to_h.stringify_keys
            r['target_page'] = r['target_page'].to_i if r['target_page'].present?
            r
          end
        end
        question.routing_rules = [] unless question.single_choice?
        if question.rating?
          question.options = question.options.is_a?(Array) && question.options.any?(&:present?) ? question.options : nil
        elsif !question.choice_type?
          question.options = nil
        end
        question.save!
      end
    end
  end
end
