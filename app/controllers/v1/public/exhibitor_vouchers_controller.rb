module V1
  module Public
    class ExhibitorVouchersController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def preview
        if params[:voucher_code].blank?
          raise ExhibitorVoucherRedemption::InvalidVoucher,
            ExhibitorVoucherRedemption::INVALID_MESSAGE
        end

        event = Event.friendly.find(params[:event_slug])
        booth_price = event.exhibitor_booth_prices.find_by(id: params[:exhibitor_booth_price_id])
        raise ExhibitorVoucherRedemption::VoucherMismatch,
          ExhibitorVoucherRedemption::MISMATCH_MESSAGE unless booth_price

        package = selected_package(booth_price)
        base_price = package&.price || booth_price.current_price
        result = ExhibitorVoucherRedemption.preview(
          event: event,
          code: params[:voucher_code],
          booth_price: booth_price,
          package: package,
          base_price: base_price
        )

        render json: { success: true, data: { price: result[:price] } }
      rescue ExhibitorVoucherRedemption::InvalidVoucher,
             ExhibitorVoucherRedemption::VoucherMismatch => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      private

      def selected_package(booth_price)
        return if params[:exhibitor_package_id].blank?

        package = booth_price.exhibitor_packages.find_by(id: params[:exhibitor_package_id])
        return package if package

        raise ExhibitorVoucherRedemption::VoucherMismatch,
          ExhibitorVoucherRedemption::MISMATCH_MESSAGE
      end
    end
  end
end
