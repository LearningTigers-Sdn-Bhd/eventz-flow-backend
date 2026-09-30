# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module AiIntegrations
  # One chat-completion call to an OpenAI-compatible provider (the kind of
  # AiIntegration the org configures). Returns the model's text. Errors carry a
  # message that is safe to show to users: never the API key or the prompt.
  class ChatClient
    class Error < StandardError; end

    OPEN_TIMEOUT = 10
    READ_TIMEOUT = 120

    def self.call(**)
      new(**).call
    end

    def initialize(integration:, model_id:, system:, user:, temperature: 0.2, max_tokens: 2500)
      @integration = integration
      @model_id = model_id
      @system = system
      @user = user
      @temperature = temperature
      @max_tokens = max_tokens
    end

    def call
      response = post
      raise Error, failure_message(response) unless response.is_a?(Net::HTTPSuccess)

      extract_content(JSON.parse(response.body))
    rescue Error
      raise
    rescue JSON::ParserError
      raise Error, 'The AI provider returned an unreadable response'
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise Error, 'The AI provider took too long to respond'
    rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, URI::InvalidURIError
      raise Error, 'Unable to connect to the AI provider'
    end

    private

    def post
      uri = completions_uri
      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = @resolved_ip # pin to the address we vetted (closes the DNS-rebind gap)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      http.start do |connection|
        request = Net::HTTP::Post.new(uri.request_uri)
        request['Authorization'] = "Bearer #{@integration.api_key}"
        request['Content-Type'] = 'application/json'
        request['Accept'] = 'application/json'
        request.body = payload.to_json
        connection.request(request)
      end
    end

    def payload
      {
        model: @model_id,
        temperature: @temperature,
        max_tokens: @max_tokens,
        messages: [
          { role: 'system', content: @system },
          { role: 'user', content: @user }
        ]
      }
    end

    def completions_uri
      uri = URI.parse(@integration.api_url)
      raise Error, 'Provider URL must use HTTPS' unless uri.scheme == 'https'
      raise Error, 'Provider URL must include a host' if uri.host.blank?

      @resolved_ip = NetworkGuard.pick_safe_address(uri.host)
      uri.path = "#{uri.path.to_s.chomp('/')}/chat/completions"
      uri.query = nil
      uri.fragment = nil
      uri
    rescue NetworkGuard::Blocked => e
      raise Error, e.message
    end

    def extract_content(body)
      content = body.dig('choices', 0, 'message', 'content')
      raise Error, 'The AI provider returned an empty answer' if content.blank?

      content.to_s
    end

    # Status and the provider's own error text, nothing else (no request data).
    def failure_message(response)
      detail = JSON.parse(response.body).dig('error', 'message') rescue nil
      base = "The AI provider returned an error (#{response.code})"
      detail.present? ? "#{base}: #{detail.to_s.truncate(200)}" : base
    end
  end
end
