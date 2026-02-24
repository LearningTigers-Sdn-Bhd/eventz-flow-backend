require "net/http"
require "openssl"
require "json"

module Payments
  class RazorpayGateway
    API_BASE = "https://api.razorpay.com/v1".freeze

    class << self
      def create_order(amount_subunits:, receipt:, notes: {})
        payload = {
          amount: amount_subunits,
          currency: "MYR",
          receipt: receipt,
          payment_capture: 1,
          notes: notes,
        }

        response = request(:post, "/orders", payload)
        JSON.parse(response.body)
      end

      def valid_signature?(order_id:, payment_id:, signature:)
        return false if order_id.blank? || payment_id.blank? || signature.blank?

        payload = "#{order_id}|#{payment_id}"
        expected = OpenSSL::HMAC.hexdigest("SHA256", key_secret, payload)
        ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      end

      def valid_webhook_signature?(payload:, signature:)
        return false if payload.blank? || signature.blank?

        expected = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, payload)
        ActiveSupport::SecurityUtils.secure_compare(expected, signature)
      end

      def key_id
        ENV.fetch("RAZORPAY_KEY_ID")
      end

      private

      def key_secret
        ENV.fetch("RAZORPAY_KEY_SECRET")
      end

      def webhook_secret
        ENV.fetch("RAZORPAY_WEBHOOK_SECRET")
      end

      def request(method, path, payload)
        uri = URI("#{API_BASE}#{path}")
        request_class = method == :post ? Net::HTTP::Post : Net::HTTP::Get
        request = request_class.new(uri)
        request.basic_auth(key_id, key_secret)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json if payload.present?

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(request)
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise "Razorpay request failed: #{response.code} #{response.body}"
        end

        response
      end
    end
  end
end
