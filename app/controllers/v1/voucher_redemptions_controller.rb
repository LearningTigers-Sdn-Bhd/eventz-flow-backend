module V1
  class VoucherRedemptionsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_vendor!
    before_action :set_voucher, only: [:create]
    before_action :set_redeemer, only: [:create]

    # POST /v1/voucher_redemptions
    def create
      net_amount = redemption_params[:net_amount]
      if net_amount.blank?
        return error_response(
          message: 'Net amount is required',
          status: :bad_request
        )
      end

      result = VoucherRedemptionService.call(
        voucher: @voucher,
        redeemer: @redeemer,
        vendor_id: current_user.id,
        net_amount: net_amount
      )

      if result.success?
        capture_lead_for(@redeemer)

        success_response(
          data: result.data,
          message: 'Voucher redeemed successfully',
          status: :created
        )
      else
        error_response(
          message: result.error,
          status: :unprocessable_content
        )
      end
    end

    private

    def authorize_vendor!
      unless current_user.is_vendor?
        render json: {
          success: false,
          message: 'Only vendors can redeem vouchers'
        }, status: :forbidden
        return
      end
    end

    def set_voucher
      voucher_uuid = redemption_params[:voucher_uuid]
      if voucher_uuid.blank?
        render json: {
          success: false,
          message: 'Voucher UUID is required'
        }, status: :bad_request
        return
      end

      @voucher = Voucher.find_by!(voucher_uuid: voucher_uuid)
      unless @voucher.event.use_voucher?
        render json: {
          success: false,
          message: 'Voucher feature is unavailable for this event'
        }, status: :forbidden
        return
      end
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        message: 'Voucher not found'
      }, status: :not_found
      return
    end

    def set_redeemer
      # Support User, Visitor, and Ticket redemptions
      if redemption_params[:ticket_id].present?
        @redeemer = Ticket.find_by!(public_id: redemption_params[:ticket_id])
      elsif redemption_params[:visitor_id].present?
        @redeemer = Visitor.find_by!(public_id: redemption_params[:visitor_id])
      elsif redemption_params[:user_id].present?
        @redeemer = User.find(redemption_params[:user_id])
      else
        @redeemer = current_user
      end
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        message: 'Redeemer not found'
      }, status: :not_found
      return
    end

    # A successful redemption is proof the vendor met this attendee in person,
    # so it doubles as a lead capture — no separate lead scan required.
    # Never lets a lead-capture hiccup fail an already-successful voucher redemption.
    def capture_lead_for(redeemer)
      return unless redeemer.is_a?(Ticket) || redeemer.is_a?(Visitor)

      event_vendor = EventVendor.find_by(event_id: @voucher.event_id, vendor_id: current_user.id)
      return unless event_vendor

      EventLead.find_or_create_by!(leadable: redeemer, event_vendor: event_vendor) do |lead|
        lead.scanned_by = current_user
      end
    rescue StandardError => e
      Rails.logger.error("Failed to capture lead from voucher redemption: #{e.message}")
    end

    def redemption_params
      params.require(:voucher_redemption).permit(
        :voucher_uuid,
        :user_id,
        :visitor_id,
        :ticket_id,
        :net_amount
      )
    end
  end
end
