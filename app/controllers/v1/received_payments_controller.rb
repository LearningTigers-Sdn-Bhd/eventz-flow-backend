module V1
  class ReceivedPaymentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :ensure_exhibitor_management_enabled

    # GET /v1/events/:event_id/received_payments
    # Returns all ExhibitorKitPayments where the current user is the payee
    # Works for: contractors (for their rentable items) and org_owners (for their printing services)
    def index
      @payments = ExhibitorKitPayment
                    .joins(exhibitor_kit: :event_vendor)
                    .where(payee_id: current_user.id)
                    .where(event_vendors: { event_id: @event.id })
                    .includes(
                      :payee,
                      exhibitor_kit: { event_vendor: :vendor },
                      exhibitor_kit_items: :rentable_item,
                      exhibitor_kit_printings: :printing_service
                    )
                    .order(created_at: :desc)

      render json: @payments.map { |payment| format_payment(payment) }, status: :ok
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def ensure_exhibitor_management_enabled
      return if current_user.org_owner? || @event.enable_exhibitor_management?

      render json: { error: 'Forbidden', message: 'Exhibitor management is not enabled for this event.' },
             status: :forbidden
    end

    def format_payment(payment)
      exhibitor_kit = payment.exhibitor_kit
      event_vendor = exhibitor_kit&.event_vendor
      vendor = event_vendor&.vendor

      payment.as_json(
        include: [
          { exhibitor_kit_items: { include: :rentable_item } },
          { exhibitor_kit_printings: { include: :printing_service } }
        ]
      ).merge(
        event_vendor_id: event_vendor&.id,
        payment_proof_url: payment.payment_proof.attached? ? url_for(payment.payment_proof) : payment[:payment_proof_url],
        payee_name: payment.payee&.full_name,
        payee_payment_detail: payment.payee&.payment_detail&.as_json(only: [:bank_name, :account_number, :account_name]),
        exhibitor_info: {
          company_name: exhibitor_kit&.company_name || vendor&.full_name,
          booth_number: exhibitor_kit&.booth_number,
          vendor_email: vendor&.email,
          vendor_name: vendor&.full_name
        }
      )
    end
  end
end
