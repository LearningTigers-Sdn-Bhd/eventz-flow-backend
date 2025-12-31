module V1
  class ExhibitorKitPaymentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_exhibitor_kit
    before_action :set_exhibitor_kit_payment, only: %i[show update]

    def index
      @exhibitor_kit_payments = policy_scope(@exhibitor_kit.exhibitor_kit_payments)
                                .includes(payee: :payment_detail, exhibitor_kit_items: [], exhibitor_kit_printings: [])

      render json: @exhibitor_kit_payments.map { |payment| format_payment(payment) }, status: :ok
    end

    def show
      authorize @exhibitor_kit_payment
      render json: format_payment(@exhibitor_kit_payment), status: :ok
    end

    def update
      authorize @exhibitor_kit_payment

      update_params = exhibitor_kit_payment_params

      # Auto-set status to 'submitted' when exhibitor provides payment proof
      if is_exhibitor? && (update_params[:payment_proof].present? || update_params[:payment_proof_url].present?)
        update_params = update_params.merge(status: 'submitted')
      end

      if @exhibitor_kit_payment.update(update_params)
        render json: format_payment(@exhibitor_kit_payment), status: :ok
      else
        render json: { error: 'Validation failed', errors: @exhibitor_kit_payment.errors.full_messages },
               status: :unprocessable_content
      end
    end

    private

    def format_payment(payment)
      payment.as_json(
        include: [
          { exhibitor_kit_items: { include: :rentable_item } },
          { exhibitor_kit_printings: { include: :printing_service } }
        ]
      ).merge(
        payment_proof_url: payment.payment_proof.attached? ? url_for(payment.payment_proof) : payment[:payment_proof_url],
        payee_name: payment.payee.full_name,
        payee_payment_detail: payment.payee.payment_detail&.as_json(only: [:bank_name, :account_number, :account_name])
      )
    end

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
