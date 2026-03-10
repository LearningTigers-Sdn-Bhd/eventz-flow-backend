module V1
  class EventPaymentGatewaysController < ApplicationController
    before_action :set_event
    before_action :set_payment_gateway, only: %i[show update destroy]

    # GET /v1/events/:event_id/event_payment_gateway
    def show
      if @payment_gateway
        authorize @payment_gateway
        render json: gateway_response(@payment_gateway), status: :ok
      else
        render json: { data: nil, payment_gateway_type: 'default' }, status: :ok
      end
    end

    # POST /v1/events/:event_id/event_payment_gateway
    def create
      @payment_gateway = @event.build_event_payment_gateway(gateway_params)
      authorize @payment_gateway

      if @payment_gateway.save
        render json: gateway_response(@payment_gateway), status: :created
      else
        render json: { errors: @payment_gateway.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PUT /v1/events/:event_id/event_payment_gateway
    def update
      authorize @payment_gateway

      if @payment_gateway.update(gateway_params)
        render json: gateway_response(@payment_gateway), status: :ok
      else
        render json: { errors: @payment_gateway.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/event_payment_gateway
    def destroy
      authorize @payment_gateway
      @payment_gateway.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_payment_gateway
      @payment_gateway = @event.event_payment_gateway
    end

    def gateway_params
      params.require(:event_payment_gateway).permit(:provider, :key_id, :key_secret, :webhook_secret)
    end

    def gateway_response(gateway)
      {
        data: {
          id: gateway.id,
          provider: gateway.provider,
          key_id: gateway.key_id,
          has_key_secret: gateway.key_secret.present?,
          has_webhook_secret: gateway.webhook_secret.present?,
          created_at: gateway.created_at,
          updated_at: gateway.updated_at
        },
        payment_gateway_type: 'custom'
      }
    end
  end
end
