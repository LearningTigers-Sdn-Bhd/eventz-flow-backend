module V1
  class ExhibitorVouchersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event, only: %i[index create]
    before_action :set_exhibitor_voucher, only: %i[destroy]

    def index
      vouchers = policy_scope(
        @event.exhibitor_vouchers.includes(:exhibitor_booth_price, :exhibitor_package)
      )
      render json: vouchers.map { |voucher| serialize_voucher(voucher) }
    end

    def create
      voucher = @event.exhibitor_vouchers.new(exhibitor_voucher_params)
      voucher.code = ExhibitorVoucher.generate_code
      authorize voucher

      if voucher.save
        render json: serialize_voucher(voucher), status: :created
      else
        render json: voucher.errors, status: :unprocessable_content
      end
    end

    def destroy
      authorize @exhibitor_voucher

      @exhibitor_voucher.with_lock do
        if @exhibitor_voucher.redeemed? && !current_user.org_owner?
          return render json: { error: 'A redeemed voucher cannot be deleted' },
                        status: :unprocessable_content
        end

        @exhibitor_voucher.destroy!
      end

      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_exhibitor_voucher
      @exhibitor_voucher = ExhibitorVoucher.find(params[:id])
    end

    def exhibitor_voucher_params
      params.require(:exhibitor_voucher).permit(
        :exhibitor_booth_price_id,
        :exhibitor_package_id,
        :discount_type,
        :discount_value
      )
    end

    def serialize_voucher(voucher)
      voucher.as_json.merge(
        'booth_price_label' => voucher.exhibitor_booth_price&.label,
        'package_name' => voucher.exhibitor_package&.name
      )
    end
  end
end
