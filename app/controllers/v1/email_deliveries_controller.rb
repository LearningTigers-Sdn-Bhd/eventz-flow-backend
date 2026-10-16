module V1
  class EmailDeliveriesController < ApplicationController
    def index
      authorize EmailDelivery

      scope = policy_scope(EmailDelivery).recent
      scope = scope.for_status(params[:status])
      scope = scope.for_recipient(params[:recipient])
      scope = scope.for_event(params[:event_id])
      scope = scope.for_search(params[:search])
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

    # Row counts per status for the Email Log summary chips; honours the event
    # filter only so the chips stay stable while the list is being filtered.
    def summary
      authorize EmailDelivery, :summary?

      counts = policy_scope(EmailDelivery).for_event(params[:event_id]).group(:status).count
      render json: { data: counts }, status: :ok
    end

    def settings
      authorize EmailDelivery, :settings?

      # Optional params preview a change (rows_to_purge) without saving it.
      setting = EmailLogSetting.current
      setting.assign_attributes(settings_params)
      return render json: { errors: setting.errors.full_messages }, status: :unprocessable_content unless setting.valid?

      render json: { data: serialize_settings(setting) }, status: :ok
    end

    def update_settings
      authorize EmailDelivery, :update_settings?

      setting = EmailLogSetting.current
      if setting.update(settings_params)
        render json: { data: serialize_settings(setting) }, status: :ok
      else
        render json: { errors: setting.errors.full_messages }, status: :unprocessable_content
      end
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

    # rows_to_purge previews what the next nightly run would delete, so org
    # owners can see the effect of a shorter window before saving it.
    def serialize_settings(setting)
      {
        retention_days: setting.retention_days,
        protected_retention_days: setting.protected_retention_days,
        purge_enabled: setting.purge_enabled,
        rows_to_purge: setting.purgeable.count
      }
    end

    def settings_params
      params.permit(:retention_days, :protected_retention_days, :purge_enabled)
    end

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
