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

      update_params = exhibitor_kit_payment_params

      # Auto-set status to 'submitted' when exhibitor provides payment proof
      if is_exhibitor? && update_params[:payment_proof_url].present?
        update_params = update_params.merge(status: 'submitted')
      end

      if @exhibitor_kit_payment.update(update_params)
        render json: @exhibitor_kit_payment
      else
        render json: { errors: @exhibitor_kit_payment.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def is_exhibitor?
      @exhibitor_kit.event_vendor.vendor_id == current_user.id
    end

    def set_exhibitor_kit
      @exhibitor_kit = ExhibitorKit.find(params[:exhibitor_kit_id])
    end

    def set_exhibitor_kit_payment
      @exhibitor_kit_payment = @exhibitor_kit.exhibitor_kit_payments.find(params[:id])
    end

    def exhibitor_kit_payment_params
      permitted = policy(@exhibitor_kit_payment).permitted_attributes_for_update
      params.require(:exhibitor_kit_payment).permit(*permitted)
    end
  end
end
