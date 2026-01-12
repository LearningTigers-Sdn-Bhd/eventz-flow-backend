module V1
  class EventSponsorshipPaymentsController < ApplicationController
    before_action :set_sponsorship
    before_action :set_payment, only: [:update, :destroy]
    before_action :authorize_payment, only: [:update, :destroy]

    # GET /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_payments
    def index
      authorize EventSponsorshipPayment
      @payments = policy_scope(EventSponsorshipPayment)
                    .where(event_sponsorship: @sponsorship)
                    .order(received_at: :desc)
                    .includes(:created_by, :updated_by)
      render json: @payments, include: ['created_by', 'updated_by']
    end

    # POST /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_payments
    def create
      @payment = @sponsorship.event_sponsorship_payments.new(payment_params)
      @payment.created_by = current_user
      @payment.updated_by = current_user
      authorize @payment

      if @payment.save
        render json: @payment, status: :created
      else
        render json: @payment.errors, status: :unprocessable_entity
      end
    end

    # PATCH/PUT /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_payments/:id
    def update
      @payment.assign_attributes(payment_params)
      @payment.updated_by = current_user
      
      if @payment.save
        render json: @payment
      else
        render json: @payment.errors, status: :unprocessable_entity
      end
    end

    # DELETE /v1/event_sponsorships/:event_sponsorship_id/event_sponsorship_payments/:id
    def destroy
      @payment.soft_delete
      head :no_content
    end

    private

    def set_sponsorship
      @sponsorship = EventSponsorship.find(params[:event_sponsorship_id])
    end

    def set_payment
      @payment = @sponsorship.event_sponsorship_payments.find(params[:id])
    end

    def authorize_payment
      authorize @payment
    end

    def payment_params
      params.require(:event_sponsorship_payment).permit(
        :amount,
        :currency,
        :received_at,
        :method,
        :reference_no,
        :notes
      )
    end
  end
end
