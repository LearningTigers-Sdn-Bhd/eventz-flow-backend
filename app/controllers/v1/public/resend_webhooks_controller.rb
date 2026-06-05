module V1
  module Public
    class ResendWebhooksController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create
        payload = request.raw_post
        verify_signature!(payload)
        event = JSON.parse(payload)

        EmailDelivery::WebhookProcessor.call(event)

        render json: { success: true }, status: :ok
      rescue JSON::ParserError
        render json: { success: false, message: 'Invalid JSON' }, status: :bad_request
      rescue StandardError => e
        Rails.logger.warn("Invalid Resend webhook: #{e.message}")
        render json: { success: false, message: 'Invalid signature' }, status: :unauthorized
      end

      private

      def verify_signature!(payload)
        Resend::Webhooks.verify(
          payload: payload,
          headers: {
            svix_id: request.headers['svix-id'],
            svix_timestamp: request.headers['svix-timestamp'],
            svix_signature: request.headers['svix-signature']
          },
          webhook_secret: webhook_secret
        )
      end

      def webhook_secret
        Rails.application.credentials.dig(:resend, :webhook_secret).presence ||
          ENV.fetch('RESEND_WEBHOOK_SECRET', '')
      end
    end
  end
end
