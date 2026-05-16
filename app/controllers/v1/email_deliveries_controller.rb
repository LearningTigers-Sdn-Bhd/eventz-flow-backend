module V1
  class EmailDeliveriesController < ApplicationController
    def index
      authorize EmailDelivery

      scope = policy_scope(EmailDelivery).recent
      scope = scope.for_status(params[:status])
      scope = scope.for_recipient(params[:recipient])
      scope = scope.where(provider_message_id: params[:provider_message_id]) if params[:provider_message_id].present?
      scope = scope.where(status: 'sent').where('sent_at <= ?', 24.hours.ago) if truthy_param?(params[:stuck_sent])
      if params[:subject].present?
        scope = scope.where('subject ILIKE ?', "%#{EmailDelivery.sanitize_sql_like(params[:subject])}%")
      end

      pagy, records = pagy(scope, limit: pagination_params[:per_page] || 25)
      render json: {
        data: records.map { |delivery| serialize_delivery(delivery) },
        pagination: pagy_metadata(pagy)
      }, status: :ok
    end

    def show
      delivery = policy_scope(EmailDelivery).find(params[:id])
      authorize delivery

      render json: { data: serialize_delivery(delivery) }, status: :ok
    end

    def resend
      delivery = policy_scope(EmailDelivery).find(params[:id])
      authorize delivery, :resend?

      result = EmailDelivery::Resender.call(delivery)
      if result.success?
        render json: { data: serialize_delivery(result.delivery) }, status: :accepted
      else
        render json: { errors: result.errors }, status: :unprocessable_content
      end
    end

    private

    def serialize_delivery(delivery)
      delivery.as_json(
        only: %i[
          id provider provider_message_id mailer_name mailer_action recipient recipients
          subject status related_type related_id sent_at delivered_at failed_at bounced_at
          complained_at suppressed_at last_error failure_reason retry_count next_retry_at
          resend_of_id created_at updated_at
        ]
      )
    end

    def truthy_param?(value)
      ActiveModel::Type::Boolean.new.cast(value)
    end
  end
end
