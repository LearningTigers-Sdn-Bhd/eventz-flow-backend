# app/services/business_matching_service.rb
require 'net/http'
require 'json'
require 'openssl'

class BusinessMatchingService < BaseService
  WEBHOOK_URL = "https://webhook.saleschatalyst.com/webhook/693921fb30946fd02504c059".freeze

  def fetch_events(event_id, force_refresh: false)
    cache_key = "business_matching_events_#{event_id}"
    pending_key = "business_matching_events_pending_#{event_id}"

    unless force_refresh
      cached_data = Rails.cache.read(cache_key)
      return BaseService::ServiceResult.new(success: true, data: cached_data) if cached_data.present?

      # Prevent infinite loops: if we recently triggered a fetch, wait for the callback.
      if Rails.cache.read(pending_key)
        return BaseService::ServiceResult.new(success: true, data: [])
      end
    end

    payload = {
      action: "Fetch Events",
      event_id: event_id,
      user_email: user.email,
      user_name: user.full_name,
      user_id: user.id
    }
    Rails.logger.info "BusinessMatching Request Payload: #{payload.inspect}"
    response = _send_request(payload)
    
    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
        # Async response. Mark as pending to avoid loop and return empty array.
        Rails.cache.write(pending_key, true, expires_in: 2.minutes)
        BaseService::ServiceResult.new(success: true, data: [])
      elsif response.data.is_a?(Hash) && (response.data["output"].is_a?(Array) || response.data["data"].is_a?(Array) || response.data["results"].is_a?(Array))
        # Synchronous response
        raw_events = response.data["output"] || response.data["data"] || response.data["results"]
        events = _transform_events(raw_events)
        Rails.cache.write(cache_key, events, expires_in: 1.hour)
        BaseService::ServiceResult.new(success: true, data: events)
      else
        # Fallback or unexpected
        BaseService::ServiceResult.new(success: true, data: [])
      end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_availability(bm_event_id)
    payload = {
      action: "Fetch Available Date",
      bm_event_id: bm_event_id
    }
    response = _send_request(payload)

    if response.success?
      if response.data.is_a?(Hash) && response.data["accepted"] == true
         BaseService::ServiceResult.new(success: true, data: { dates: [] })
      else
         # Transform availability if needed
         raw_data = response.data["output"] || response.data["data"] || response.data
         # Expected format: { dates: [...] }
         if raw_data.is_a?(Array)
            dates = raw_data.map do |item|
                {
                    day: item["day"],
                    date: item["date"],
                    slots: item["slots"].to_i
                }
            end
            BaseService::ServiceResult.new(success: true, data: { dates: dates })
         else
            BaseService::ServiceResult.new(success: true, data: raw_data)
         end
      end
    else
      response
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  private

  def _transform_events(raw_events)
    raw_events.map do |event_data|
      {
        id: event_data["id"] || event_data["_id"],
        title: event_data["title"],
        duration: event_data["slotDuration"],
        location: event_data["locationLink"],
        admin_email: event_data["adminEmail"],
        admin_wa_number: event_data["adminWaNumber"]
      }
    end
  end

  def _send_request(payload)
    uri = URI.parse(WEBHOOK_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    # Bypass SSL verification to avoid "unable to get certificate CRL" error
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    request.body = payload.to_json

    response = http.request(request)

    case response
    when Net::HTTPSuccess
      parsed_body = JSON.parse(response.body)
      BaseService::ServiceResult.new(success: true, data: parsed_body)
    else
      BaseService::ServiceResult.new(success: false, errors: response.body, status: response.code.to_i)
    end
  rescue JSON::ParserError => e
    BaseService::ServiceResult.new(success: false, errors: "Failed to parse JSON response: #{e.message}", status: :bad_gateway)
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: "HTTP request failed: #{e.message}", status: :internal_server_error)
  end
end
