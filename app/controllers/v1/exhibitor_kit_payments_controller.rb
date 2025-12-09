module V1
  class ExhibitorKitPaymentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_exhibitor_kit
    before_action :set_exhibitor_kit_payment, only: %i[show update]

    def index
      @exhibitor_kit_payments = policy_scope(@exhibitor_kit.exhibitor_kit_payments)
                                .includes(:exhibitor_kit_items, :exhibitor_kit_printings) # Eager load associations
      render json: @exhibitor_kit_payments.as_json(
        include: [
          { exhibitor_kit_items: { include: :rentable_item } },
          { exhibitor_kit_printings: { include: :printing_service } }
        ]
      )
    end

    def show
      authorize @exhibitor_kit_payment
      render json: @exhibitor_kit_payment
    end

    def update
      authorize @exhibitor_kit_payment
      if @exhibitor_kit_payment.update(exhibitor_kit_payment_params)
        render json: @exhibitor_kit_payment
      else
        render json: { errors: @exhibitor_kit_payment.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def set_exhibitor_kit
      @exhibitor_kit = ExhibitorKit.find(params[:exhibitor_kit_id])
    end

    def set_exhibitor_kit_payment
      @exhibitor_kit_payment = @exhibitor_kit.exhibitor_kit_payments.find(params[:id])
    end

    def exhibitor_kit_payment_params
      params.require(:exhibitor_kit_payment).permit(:amount, :status, :payment_source, :payment_proof_url, :external_ref, :note, :paid_at)
    end
  end
end
