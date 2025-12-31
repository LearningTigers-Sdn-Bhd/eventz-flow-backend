module V1
  class PaymentDetailsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_payment_detail, only: %i[show update destroy]

    def show
      authorize @payment_detail
      render json: @payment_detail, status: :ok
    end

    def me
      @payment_detail = current_user.payment_detail

      if @payment_detail
        render json: @payment_detail, status: :ok
      else
        render json: { message: 'No payment details found' }, status: :not_found
      end
    end

    def create
      if PaymentDetail.exists?(user_id: current_user.id)
        render json: { error: 'Payment details already exist' }, status: :unprocessable_content
        return
      end

      @payment_detail = current_user.build_payment_detail(payment_detail_params)
      authorize @payment_detail

      if @payment_detail.save
        render json: @payment_detail, status: :created
      else
        render json: { error: 'Validation failed', errors: @payment_detail.errors.full_messages },
               status: :unprocessable_content
      end
    end

    def update
      authorize @payment_detail

      if @payment_detail.update(payment_detail_params)
        render json: @payment_detail, status: :ok
      else
        render json: { error: 'Validation failed', errors: @payment_detail.errors.full_messages },
               status: :unprocessable_content
      end
    end

    def destroy
      authorize @payment_detail
      @payment_detail.destroy
      head :no_content
    end

    private

    def set_payment_detail
      @payment_detail = current_user.payment_detail
      raise ActiveRecord::RecordNotFound, 'Payment detail not found' unless @payment_detail
    end

    def payment_detail_params
      params.require(:payment_detail).permit(:bank_name, :account_number, :account_name)
    end
  end
end
