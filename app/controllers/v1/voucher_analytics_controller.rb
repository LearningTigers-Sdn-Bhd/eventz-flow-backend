module V1
  class VoucherAnalyticsController < ApplicationController
    before_action :set_event

    def index
      vouchers_scope = Voucher.for_event(@event)
      redemption_logs_scope = VoucherRedemptionLog.for_event(@event)

      if params[:vendor_id].present?
        vouchers_scope = vouchers_scope.where(vendor_id: params[:vendor_id])
        redemption_logs_scope = redemption_logs_scope.joins(:voucher).where(vouchers: { vendor_id: params[:vendor_id] })
      end

      total_vouchers_issued = vouchers_scope.sum(:total_redemption_available)
      total_redemptions = redemption_logs_scope.count
      event_redemption_rate = total_vouchers_issued.zero? ? 0 : (total_redemptions.to_f / total_vouchers_issued) * 100

      render json: {
        total_vouchers_issued: total_vouchers_issued,
        total_redemptions: total_redemptions,
        event_redemption_rate: event_redemption_rate,
        total_discount_value: redemption_logs_scope.total_discount_value,
        total_sales: redemption_logs_scope.total_sales,
        daily_redemption_trend: redemption_logs_scope.daily_redemption_trend,
        top_scanned_vouchers: redemption_logs_scope.top_scanned_vouchers,
        latest_redemption_transactions: redemption_logs_scope.latest_redemption_transactions
      }
    end

    # GET /v1/events/:event_id/voucher_analytics/redemption_logs
    # Fetch all redemption logs for an event with optional filters
    def redemption_logs
      authorize @event, :view_redemption_logs?, policy_class: VoucherRedemptionLogPolicy

      logs = policy_scope(VoucherRedemptionLog.for_event(@event))
               .includes(:voucher, :redeemer_staff)
               .preload(:redeemer)
               .order(redemption_timestamp: :desc)

      # --- Optional Filters (Applied on top of RBAC) ---
      logs = logs.where(voucher_id: params[:voucher_id]) if params[:voucher_id].present?

      # Allow filtering by vendor_id ONLY if the user is allowed to see other vendors (i.e., not a vendor themselves)
      if params[:vendor_id].present? && !current_user.is_vendor?
        logs = logs.joins(:voucher).where(vouchers: { vendor_id: params[:vendor_id] })
      end

      render json: logs.as_json(include: {
        voucher: { only: [:id, :title, :voucher_uuid, :voucher_code, :voucher_type] },
        redeemer: { only: [:id, :full_name, :email, :phone, :public_id] },
        redeemer_staff: { only: [:id, :full_name, :email] }
      })
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
