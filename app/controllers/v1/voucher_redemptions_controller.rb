module V1
  class VoucherRedemptionsController < ApplicationController
    before_action :authenticate_user!
    before_action :authorize_vendor!
    before_action :set_voucher, only: [:create]
    before_action :set_redeemer, only: [:create]

    # POST /v1/voucher_redemptions
    def create
      gross_amount = redemption_params[:gross_amount]
      if gross_amount.blank?
        return error_response(
          message: 'Gross amount is required',
          status: :bad_request
        )
      end

      result = VoucherRedemptionService.call(
        voucher: @voucher,
        redeemer: @redeemer,
        vendor_id: current_user.id,
        gross_amount: gross_amount
      )

      if result.success?
        success_response(
          data: result.data,
          message: 'Voucher redeemed successfully',
          status: :created
        )
      else
        error_response(
          message: result.error,
          status: :unprocessable_entity
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
    rescue ActiveRecord::RecordNotFound
      render json: {
        success: false,
        message: 'Voucher not found'
      }, status: :not_found
      return
    end

    def set_redeemer
      # Support both User and Visitor redemptions
      if redemption_params[:visitor_id].present?
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

    def redemption_params
      params.require(:voucher_redemption).permit(
        :voucher_uuid,
        :user_id,
        :visitor_id,
        :gross_amount
      )
    end
  end
end
