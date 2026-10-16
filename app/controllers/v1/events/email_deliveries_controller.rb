module V1
  module Events
    # Organizer-facing delivery status of the emails sent for one event. A
    # trimmed view of EmailDelivery: no provider ids, payloads or retry state.
    class EmailDeliveriesController < ApplicationController
      before_action :set_event

      # Outcome groups shown to organizers, mapped to the raw statuses.
      STATUS_GROUPS = {
        'delivered' => %w[delivered],
        'sent' => %w[sent],
        'pending' => %w[queued sending],
        'problem' => EmailDelivery::PROBLEM_STATUSES
      }.freeze

      def index
        authorize @event, :view_email_status?

        scope = base_scope.includes(:related).recent
        scope = scope.where(status: STATUS_GROUPS[params[:status_group]]) if STATUS_GROUPS.key?(params[:status_group])
        scope = scope.where(mailer_action: params[:email_type]) if params[:email_type].present?
        scope = scope.for_recipient(params[:recipient]) if params[:recipient].present?

        pagy, records = pagy(scope, limit: pagination_params[:per_page] || 25)
        render json: {
          data: records.map { |delivery| serialize(delivery) },
          pagination: pagy_metadata(pagy)
        }, status: :ok
      end

      def summary
        authorize @event, :view_email_status?

        data = group_counts
        email_types = base_scope.distinct.order(:mailer_action).pluck(:mailer_action)
        render json: { data: data, email_types: email_types }, status: :ok
      end

      # Every email for the event as a styled Excel workbook, split by outcome.
      def export
        authorize @event, :view_email_status?

        workbook = EmailDelivery::StatusReportWorkbook.new(@event, deliveries: base_scope.includes(:related).recent)
        send_data workbook.call, filename: workbook.filename, disposition: 'attachment',
                                 type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      end

      # Optional `email` corrects the attendee's address first (tickets only),
      # so a bounce can be retried to the right mailbox.
      def resend
        authorize @event, :view_email_status?

        delivery = base_scope.find(params[:id])
        error = correct_recipient(delivery)
        return render json: { errors: [error] }, status: :unprocessable_content if error

        result = EmailDelivery::Resender.call(delivery, organizer: true)
        if result.success?
          render json: { data: serialize(result.delivery) }, status: :accepted
        else
          render json: { errors: result.errors }, status: :unprocessable_content
        end
      end

      private

      def group_counts
        counts = base_scope.group(:status).count
        STATUS_GROUPS.transform_values { |statuses| counts.values_at(*statuses).compact.sum }
      end

      def set_event
        @event = Event.friendly.find(params[:event_id])
      end

      # Rows already retried are hidden: the retry row carries the outcome.
      def base_scope
        EmailDelivery.where(event_id: @event.id)
                     .where.not(status: 'skipped')
                     .not_retried
      end

      def correct_recipient(delivery)
        email = params[:email].to_s.strip
        return if email.blank?

        ticket = delivery.related
        return 'Only ticket emails can be corrected' unless ticket.is_a?(Ticket) && ticket.event_id == @event.id
        return if ticket.update(attendee_email: email)

        ticket.errors.full_messages.to_sentence
      end

      def serialize(delivery)
        ticket = delivery.related if delivery.related_type == 'Ticket'
        {
          id: delivery.id,
          email_type: delivery.mailer_action,
          recipient: delivery.recipient,
          subject: delivery.subject,
          status: delivery.status,
          problem: delivery.failure_reason,
          created_at: delivery.created_at,
          sent_at: delivery.sent_at,
          delivered_at: delivery.delivered_at,
          problem_at: delivery.bounced_at || delivery.complained_at || delivery.suppressed_at || delivery.failed_at,
          attendee: ticket && { ticket_id: ticket.id, name: ticket.attendee_name },
          can_resend: delivery.eligible_for_organizer_resend?
        }
      end
    end
  end
end
