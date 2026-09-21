require 'json'
require 'ipaddr'
require 'net/http'
require 'resolv'
require 'uri'

module AiIntegrations
  class ErrorAnalyzer
    class Error < StandardError; end

    BLOCKED_NETWORKS = AvailableModelsFetcher::BLOCKED_NETWORKS

    SYSTEM_PROMPT = <<~PROMPT.freeze
      You are diagnosing a backend API error for an events platform. Given the request
      path, HTTP method, error message and sanitized request details, respond with ONLY
      a JSON object (no markdown fences) with exactly these keys:
      "cause" (1-2 sentences on the likely root cause),
      "suggested_fix" (1-2 sentences on what to do about it),
      "severity" (one of "low", "medium", "high").
    PROMPT

    def self.call(activity, model_id: nil)
      new(activity, model_id: model_id).call
    end

    def initialize(activity, model_id: nil)
      @activity = activity
      @model = (AiModel.find_by(id: model_id) if model_id.present?) || AiModel.find_by(is_default: true)
    end

    def call
      raise Error, 'Activity is not a failed request' unless @activity.result == 'failed'
      raise Error, 'No default AI model configured' if @model.blank?

      @integration = @model.ai_integration
      response = request_completion
      raise Error, 'Provider returned an unsuccessful response' unless response.is_a?(Net::HTTPSuccess)

      diagnosis = parse_diagnosis(JSON.parse(response.body))
      @activity.update!(ai_diagnosis: diagnosis, ai_diagnosed_at: Time.current)
      diagnosis
    rescue Error
      raise
    rescue JSON::ParserError
      raise Error, 'Provider returned invalid diagnosis data'
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, URI::InvalidURIError
      raise Error, 'Unable to connect to provider'
    end

    private

    def request_completion
      uri = completions_uri
      http = Net::HTTP.new(uri.host, uri.port)
      http.ipaddr = @resolved_ip
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = 60

      http.start do |connection|
        request = Net::HTTP::Post.new(uri.request_uri)
        request['Authorization'] = "Bearer #{@integration.api_key}"
        request['Content-Type'] = 'application/json'
        request['Accept'] = 'application/json'
        request.body = completion_payload.to_json
        connection.request(request)
      end
    end

    def completion_payload
      {
        model: @model.model_id,
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: error_context.to_json }
        ],
        temperature: 0.2
      }
    end

    def error_context
      {
        http_method: @activity.http_method,
        path: @activity.path,
        error_message: @activity.error_message,
        details: @activity.details
      }
    end

    def completions_uri
      uri = URI.parse(@integration.api_url)
      raise Error, 'Provider URL must use HTTPS' unless uri.scheme == 'https'
      raise Error, 'Provider URL must include a host' if uri.host.blank?

      @resolved_ip = pick_safe_address(uri.host)

      uri.path = "#{uri.path.to_s.chomp('/')}/chat/completions"
      uri.query = nil
      uri.fragment = nil
      uri
    rescue Resolv::ResolvError
      raise Error, 'Provider URL could not be resolved'
    end

    def pick_safe_address(host)
      addresses = Resolv.getaddresses(host)
      raise Error, 'Provider URL could not be resolved' if addresses.empty?
      if addresses.any? { |address| blocked_address?(address) }
        raise Error, 'Provider URL must not target a private or local network'
      end

      addresses.first
    end

    def blocked_address?(address)
      ip_address = IPAddr.new(address)
      BLOCKED_NETWORKS.any? { |network| network.include?(ip_address) }
    rescue IPAddr::InvalidAddressError
      true
    end

    def parse_diagnosis(payload)
      content = payload.dig('choices', 0, 'message', 'content')
      raise Error, 'Provider returned an unsupported completion response' if content.blank?

      parsed = JSON.parse(content)
      severity = parsed['severity'].to_s.downcase
      severity = 'medium' unless %w[low medium high].include?(severity)

      {
        'cause' => parsed['cause'].to_s.strip.presence || 'Unable to determine cause.',
        'suggested_fix' => parsed['suggested_fix'].to_s.strip.presence || 'No suggestion available.',
        'severity' => severity
      }
    rescue JSON::ParserError
      raise Error, 'Provider returned invalid diagnosis data'
    end
  end
end
