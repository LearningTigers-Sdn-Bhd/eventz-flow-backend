require "net/http"
require "openssl"
require "json"

module Payments
  class RazorpayGateway
    API_BASE = "https://api.razorpay.com/v1".freeze

    attr_reader :key_id, :key_secret, :webhook_secret

    def initialize(key_id:, key_secret:, webhook_secret: nil)
      @key_id = key_id
      @key_secret = key_secret
      @webhook_secret = webhook_secret
    end

    # Build a gateway instance from an event's custom credentials or fall back to defaults
    def self.for_event(event)
      gw = event.event_payment_gateway
      if gw.present?
        new(
          key_id: gw.key_id,
          key_secret: gw.key_secret,
          webhook_secret: gw.webhook_secret
        )
      else
        default
      end
    end

    # Build a gateway instance using default credentials from Rails credentials
    def self.default
      creds = Rails.application.credentials.razorpay
      raise "Razorpay credentials not configured in Rails credentials" if creds.blank?

      new(
        key_id: creds[:key_id],
        key_secret: creds[:key_secret],
        webhook_secret: creds[:webhook_secret]
      )
    end

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
      return false if payload.blank? || signature.blank? || webhook_secret.blank?

      expected = OpenSSL::HMAC.hexdigest("SHA256", webhook_secret, payload)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end

    def fetch_payment(payment_id)
      raise ArgumentError, 'payment_id is required' if payment_id.blank?

      response = request(:get, "/payments/#{payment_id}", nil)
      JSON.parse(response.body)
    end

    private

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
