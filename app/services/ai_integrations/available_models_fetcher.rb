require 'json'
require 'ipaddr'
require 'net/http'
require 'resolv'
require 'uri'

module AiIntegrations
  class AvailableModelsFetcher
    class Error < StandardError; end

    BLOCKED_NETWORKS = %w[
      0.0.0.0/8
      10.0.0.0/8
      100.64.0.0/10
      127.0.0.0/8
      169.254.0.0/16
      172.16.0.0/12
      192.0.0.0/24
      192.0.2.0/24
      192.168.0.0/16
      198.18.0.0/15
      198.51.100.0/24
      203.0.113.0/24
      224.0.0.0/4
      240.0.0.0/4
      ::/128
      ::1/128
      ::ffff:0:0/96
      fc00::/7
      fe80::/10
      ff00::/8
    ].map { |network| IPAddr.new(network) }.freeze

    def self.call(integration)
      new(integration).call
    end

    def initialize(integration)
      @integration = integration
    end

    def call
      response = fetch_models
      raise Error, 'Provider returned an unsuccessful response' unless response.is_a?(Net::HTTPSuccess)

      normalize(JSON.parse(response.body))
    rescue Error
      raise
    rescue JSON::ParserError
      raise Error, 'Provider returned invalid model data'
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, URI::InvalidURIError
      raise Error, 'Unable to connect to provider'
    end

    private

    def fetch_models
      uri = models_uri

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: 10,
        read_timeout: 10
      ) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request['Authorization'] = "Bearer #{@integration.api_key}"
        request['Accept'] = 'application/json'
        http.request(request)
      end
    end

    def models_uri
      uri = URI.parse(@integration.api_url)
      raise Error, 'Provider URL must use HTTPS' unless uri.scheme == 'https'
      raise Error, 'Provider URL must include a host' if uri.host.blank?

      addresses = Resolv.getaddresses(uri.host)
      raise Error, 'Provider URL could not be resolved' if addresses.empty?
      if addresses.any? { |address| blocked_address?(address) }
        raise Error, 'Provider URL must not target a private or local network'
      end

      uri.path = "#{uri.path.to_s.chomp('/')}/models"
      uri.query = nil
      uri.fragment = nil
      uri
    rescue Resolv::ResolvError
      raise Error, 'Provider URL could not be resolved'
    end

    def blocked_address?(address)
      ip_address = IPAddr.new(address)
      BLOCKED_NETWORKS.any? { |network| network.include?(ip_address) }
    rescue IPAddr::InvalidAddressError
      true
    end

    def normalize(payload)
      models = if payload.is_a?(Hash)
                 payload['data'] || payload['models']
               else
                 payload
               end

      raise Error, 'Provider returned an unsupported model response' unless models.is_a?(Array)

      models.filter_map do |model|
        next unless model.is_a?(Hash)

        model_id = model['id'].to_s.strip
        next if model_id.blank?

        {
          model_id: model_id,
          model_name: model['name'].presence || model['display_name'].presence || ''
        }
      end.uniq { |model| model[:model_id] }
    end
  end
end
