# frozen_string_literal: true

module V1
  # Organizer-facing insight endpoints for a feedback form: comments, attendees
  # who have not responded yet, reminders, and the full export dataset.
  class FeedbackReportsController < ApplicationController
    EXPORT_LIMIT = 10_000
    REMINDER_LIMIT = 500
    REMINDER_COOLDOWN = 24.hours

    before_action :authenticate_user!
    before_action :set_event
    before_action :authorize_event
    before_action :set_form

    rescue_from FeedbackResponseScope::InvalidFilter do |e|
      error_response(message: e.message, status: :unprocessable_content)
    end

    # GET /v1/events/:event_id/feedback_form/comments
    # Params: q, question_id, max_rating (only responses scoring at or below it),
    # plus the shared filters (ticket_type_id, from, to), page, per_page.
    def comments
      return empty_page unless @form

      response_rating = <<~SQL.squish
        (SELECT AVG(CAST(ra.answer_text AS numeric)) FROM feedback_answers ra
         JOIN feedback_questions rq ON rq.id = ra.feedback_question_id
         WHERE ra.feedback_response_id = feedback_answers.feedback_response_id
           AND rq.question_type = #{FeedbackQuestion.question_types.fetch('rating')}
           AND ra.answer_text ~ '^[1-5]$')
      SQL

      scope = FeedbackAnswer.joins(:feedback_question)
                            .where(feedback_questions: { feedback_form_id: @form.id, question_type: :text })
                            .where(feedback_response_id: FeedbackResponseScope.call(@form, filters).select(:id))
                            .where("BTRIM(feedback_answers.answer_text) <> ''")
      scope = scope.where(feedback_question_id: params[:question_id]) if params[:question_id].present?
      scope = scope.where("#{response_rating} <= ?", params[:max_rating].to_f) if params[:max_rating].present?

      if params[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        scope = scope.joins(feedback_response: :ticket)
                     .where('feedback_answers.answer_text ILIKE :q OR tickets.attendee_name ILIKE :q ' \
                            'OR tickets.attendee_email ILIKE :q', q: like)
      end

      scope = scope.select("feedback_answers.*, #{response_rating} AS response_rating")
                   .preload(:feedback_question, feedback_response: { ticket: :ticket_type })
                   .order('feedback_answers.created_at DESC, feedback_answers.id DESC')
      pagy, records = pagy(scope, limit: pagination_params[:per_page] || 25)

      render json: {
        data: records.map { |answer| FeedbackCommentSerializer.serialize(answer) },
        pagination: pagy_metadata(pagy)
      }, status: :ok
    end

    # GET /v1/events/:event_id/feedback_form/non_responders
    def non_responders
      return empty_page unless @form

      scope = non_responder_scope
      if params[:q].present?
        like = "%#{ActiveRecord::Base.sanitize_sql_like(params[:q].strip)}%"
        scope = scope.where('tickets.attendee_name ILIKE :q OR tickets.attendee_email ILIKE :q', q: like)
      end
      scope = scope.includes(:ticket_type).order(:attendee_name, :id)
      pagy, records = pagy(scope, limit: pagination_params[:per_page] || 25)
      last_emailed = last_emailed_at(records.map(&:id))

      render json: {
        data: records.map do |ticket|
          FeedbackNonResponderSerializer.serialize(ticket, last_emailed_at: last_emailed[ticket.id])
        end,
        pagination: pagy_metadata(pagy)
      }, status: :ok
    end

    # POST /v1/events/:event_id/feedback_form/remind
    # Body: { ticket_ids: [public_id, ...] } or { all: true } (plus filters).
    # Re-sends the thank-you email (which carries the feedback link).
    def remind
      error = reminder_blocker
      return error_response(message: error, status: :unprocessable_content) if error

      scope = non_responder_scope.where.not(attendee_email: [nil, ''])
      scope = scope.where(public_id: Array(params[:ticket_ids])) unless ActiveModel::Type::Boolean.new.cast(params[:all])
      tickets = scope.limit(REMINDER_LIMIT).to_a
      recent = recently_emailed_ticket_ids(tickets.map(&:id))

      queued = 0
      tickets.each do |ticket|
        next if recent.include?(ticket.id)

        EmailDelivery::AuditedDelivery.deliver_later(
          mailer_name: 'ThankYouMailer', mailer_action: 'thank_you_email', args: [ticket], related: ticket,
          metadata: { source: 'feedback_reminder', event_id: @event.id }, dedupe: true
        )
        queued += 1
      end

      success_response(data: { queued:, skipped: tickets.length - queued }, status: :accepted)
    end

    # GET /v1/events/:event_id/feedback_form/export_data
    # Everything the panel needs to build CSV, Excel and PDF files.
    def export_data
      return error_response(message: 'No feedback form yet', status: :not_found) unless @form

      responses = FeedbackResponseScope.call(@form, filters)
      if responses.count > EXPORT_LIMIT
        return error_response(
          message: "Too many responses to export at once (limit #{EXPORT_LIMIT}). Narrow the filters and try again.",
          status: :unprocessable_content
        )
      end

      records = responses.includes(ticket: :ticket_type, feedback_answers: :feedback_question)
                         .order(submitted_at: :asc, id: :asc)

      success_response(data: {
        generated_at: Time.current,
        filters: filters,
        event: { title: @event.title, start_date: @event.start_date, end_date: @event.end_date },
        form: { title: @form.title, display_mode: @form.display_mode },
        summary: FeedbackFormSummary.call(@form, filters),
        questions: @form.feedback_questions.map { |question| FeedbackExportSerializer.question(question) },
        responses: records.map { |response| FeedbackExportSerializer.response(response) },
        comments: FeedbackExportSerializer.comments(records)
      })
    end

    # GET /v1/events/:event_id/feedback_form/ai_summary
    # The latest stored summary plus what the current user may do with it.
    def ai_summary
      return error_response(message: 'No feedback form yet', status: :not_found) unless @form

      success_response(data: ai_summary_payload)
    end

    # POST /v1/events/:event_id/feedback_form/ai_summary  (org_owner only)
    def create_ai_summary
      authorize @event, :summarize_feedback?
      return error_response(message: 'No feedback form yet', status: :not_found) unless @form

      problem = ai_summary_blocker
      return error_response(message: problem[:message], status: problem[:status]) if problem

      model = default_ai_model
      summary = @form.feedback_ai_summaries.create!(
        ai_model: model, model_name_used: ai_model_label(model), generated_by: current_user,
        filters: filters.compact_blank
      )
      FeedbackAiSummaryJob.perform_later(summary.id)
      success_response(data: ai_summary_payload, status: :accepted)
    end

    private

    def default_ai_model
      AiModel.includes(:ai_integration).find_by(is_default: true)
    end

    def ai_model_label(model)
      model.display_name.presence || model.model_id
    end

    def ai_summary_blocker
      if default_ai_model.nil?
        return { message: 'AI is not set up yet. Add a provider and a default model in AI integrations first.',
                 status: :unprocessable_content }
      end
      if @form.feedback_ai_summaries.active.exists?
        return { message: 'A summary is already being generated.', status: :conflict }
      end

      left = cooldown_seconds_left
      if left.positive?
        return { message: "Please wait #{left} seconds before generating another summary.",
                 status: :too_many_requests }
      end
      if @form.feedback_ai_summaries.where('created_at > ?', 24.hours.ago).count >= FeedbackAiSummary::DAILY_LIMIT
        return { message: 'The daily limit for AI summaries on this form has been reached. Try again tomorrow.',
                 status: :too_many_requests }
      end
      unless comments_exist?
        return { message: 'There are no comments to summarize yet.', status: :unprocessable_content }
      end

      nil
    end

    def comments_exist?
      FeedbackAnswer.joins(:feedback_question)
                    .where(feedback_questions: { feedback_form_id: @form.id, question_type: :text })
                    .where(feedback_response_id: FeedbackResponseScope.call(@form, filters).select(:id))
                    .where("BTRIM(feedback_answers.answer_text) <> ''")
                    .exists?
    end

    def cooldown_seconds_left
      last = @form.feedback_ai_summaries.newest_first.first
      return 0 unless last

      (FeedbackAiSummary::COOLDOWN - (Time.current - last.created_at)).ceil.clamp(0, FeedbackAiSummary::COOLDOWN.to_i)
    end

    def ai_summary_payload
      owner = policy(@event).summarize_feedback?
      model = default_ai_model
      latest = @form.feedback_ai_summaries.newest_first.includes(:generated_by).first
      {
        can_generate: owner,
        configured: model.present?,
        # Provider details are only for the person who can trigger a run.
        provider: owner ? model&.ai_integration&.provider : nil,
        model: owner && model ? ai_model_label(model) : nil,
        retry_after: cooldown_seconds_left,
        summary: latest && FeedbackAiSummarySerializer.serialize(latest)
      }
    end

    def set_event
      @event = Event.find(params[:event_id])
    end

    def authorize_event
      authorize @event, :update?
    end

    def set_form
      @form = @event.feedback_form
    end

    def filters
      params.permit(:ticket_type_id, :from, :to).to_h.symbolize_keys
    end

    def empty_page
      render json: {
        data: [],
        pagination: { current_page: 1, total_pages: 0, total_count: 0, per_page: 25, prev_page: nil, next_page: nil,
                      first_page: 1, last_page: 0, from: 0, to: 0 }
      }, status: :ok
    end

    def non_responder_scope
      FeedbackResponseScope.eligible_tickets(@event, ticket_type_id: params[:ticket_type_id])
                           .where.not(id: @form.feedback_responses.where.not(ticket_id: nil).select(:ticket_id))
    end

    def last_emailed_at(ticket_ids)
      EmailDelivery.where(related_type: 'Ticket', related_id: ticket_ids, mailer_name: 'ThankYouMailer',
                          mailer_action: 'thank_you_email', status: EmailDelivery::AuditedDelivery::IN_FLIGHT_STATUSES)
                   .group(:related_id).maximum(:created_at)
    end

    def recently_emailed_ticket_ids(ticket_ids)
      EmailDelivery.where(related_type: 'Ticket', related_id: ticket_ids, mailer_name: 'ThankYouMailer',
                          mailer_action: 'thank_you_email', status: EmailDelivery::AuditedDelivery::IN_FLIGHT_STATUSES)
                   .where('created_at >= ?', REMINDER_COOLDOWN.ago)
                   .distinct.pluck(:related_id).to_set
    end

    # Same conditions as a single ticket's "resend feedback email".
    def reminder_blocker
      if @form.nil? then 'No feedback form yet'
      elsif !@event.ended? then 'Event has not ended yet'
      elsif @event.event_email_setting&.email_enabled?('ThankYouMailer', 'thank_you_email') == false
        'Thank you email is turned off for this event'
      elsif !ThankYouMailer.feedback_link_available?(@event)
        'Feedback link is off, or the feedback form is inactive or has no questions'
      end
    end
  end
end
