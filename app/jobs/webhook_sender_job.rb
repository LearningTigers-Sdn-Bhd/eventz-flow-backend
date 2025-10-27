require 'net/http'

class WebhookSenderJob < ApplicationJob
  queue_as :webhooks
  
  # Retry on network/server errors
  retry_on Net::OpenTimeout, wait: :exponentially_longer, attempts: 5
  retry_on Net::ReadTimeout, wait: :exponentially_longer, attempts: 5
  retry_on SocketError, wait: :exponentially_longer, attempts: 3

  def perform(webhook_url, payload)
    uri = validate_webhook_url(webhook_url)
    
    response = Net::HTTP.start(
      uri.host, 
      uri.port,
      use_ssl: uri.scheme == 'https',
      open_timeout: 10,
      read_timeout: 10
    ) do |http|
      request = Net::HTTP::Post.new(uri.request_uri)
      request['Content-Type'] = 'application/json'
      request.body = payload.to_json
      http.request(request)
    end
    
    # Log result
    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "Webhook delivered: #{payload[:event_type]} to #{webhook_url}"
    else
      Rails.logger.warn "Webhook failed: #{response.code} - #{webhook_url}"
    end
    
  rescue StandardError => e
    Rails.logger.error "Webhook error: #{e.message} - #{webhook_url}"
    raise  # Re-raise to trigger retry
  end

  private

  def validate_webhook_url(url)
    uri = URI.parse(url)
    
    # Security: Only HTTP/HTTPS allowed
    unless %w[http https].include?(uri.scheme)
      raise ArgumentError, "Invalid webhook URL scheme"
    end
    
    # Security: Block private IPs to prevent SSRF attacks
    if uri.host.match?(/^(localhost|127\.|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)/)
      raise ArgumentError, "Webhook URL cannot target private IPs"
    end
    
    uri
  rescue URI::InvalidURIError => e
    raise ArgumentError, "Invalid webhook URL: #{e.message}"
  end
end
