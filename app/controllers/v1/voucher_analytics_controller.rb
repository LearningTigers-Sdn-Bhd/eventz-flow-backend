module V1
  class VoucherAnalyticsController < ApplicationController
    before_action :set_event

    def index
      redemption_logs = VoucherRedemptionLog.for_event(@event)
      total_vouchers_issued = Voucher.for_event(@event).count
      total_redemptions = redemption_logs.count
      event_redemption_rate = total_vouchers_issued.zero? ? 0 : (total_redemptions.to_f / total_vouchers_issued) * 100

      render json: {
        total_vouchers_issued: total_vouchers_issued,
        total_redemptions: total_redemptions,
        event_redemption_rate: event_redemption_rate,
        total_discount_value: redemption_logs.total_discount_value,
        total_sales: redemption_logs.total_sales,
        daily_redemption_trend: redemption_logs.daily_redemption_trend,
        top_scanned_vouchers: redemption_logs.top_scanned_vouchers,
        latest_redemption_transactions: redemption_logs.latest_redemption_transactions
      }
    end

    # GET /v1/events/:event_id/voucher_analytics/redemption_logs
    # Fetch all redemption logs for an event with optional filters
    def redemption_logs
      logs = VoucherRedemptionLog.for_event(@event)
                                  .includes(:voucher, :redeemer_staff)
                                  .preload(:redeemer)
                                  .order(redemption_timestamp: :desc)

      # Optional filters
      logs = logs.where(voucher_id: params[:voucher_id]) if params[:voucher_id].present?
      logs = logs.where(redeemer_staff_id: params[:vendor_id]) if params[:vendor_id].present?

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
