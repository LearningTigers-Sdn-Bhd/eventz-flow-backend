require 'net/http'
require 'json'
require 'openssl'

class ElevenLabsService < BaseService
  BASE_URL = "https://api.elevenlabs.io/v1".freeze
  DEFAULT_MODEL = "eleven_multilingual_v2".freeze

  def initialize(user = nil)
    super(user)
  end

  # Adds a new voice to ElevenLabs using multiple audio samples
  def add_voice(cloned_voice)
    api_key = ENV['ELEVENLABS_API_KEY']
    return ServiceResult.new(success: false, errors: ["Missing audio samples"]) if cloned_voice.audio_samples.blank?
    return ServiceResult.new(success: false, errors: ["ElevenLabs API key missing"]) if api_key.blank?

    url = URI("#{BASE_URL}/voices/add")
    request = Net::HTTP::Post.new(url)
    request["xi-api-key"] = api_key

    # Using a safer approach for multipart/form-data with multiple files
    form_data = [
      ["name", cloned_voice.name],
      ["description", "Cloned via EventzFlow. Total samples: #{cloned_voice.audio_samples.count}"]
    ]

    cloned_voice.audio_samples.each do |sample|
      blob = sample.blob
      # ElevenLabs expects multiple "files" fields
      form_data << ["files", blob.download, { filename: blob.filename.to_s, content_type: blob.content_type }]
    end

    request.set_form(form_data, "multipart/form-data")

    response = http_client(url).request(request)
    parse_response(response)
  end

  # Synthesizes text to speech
  def synthesize(text, voice_id, settings = {})
    api_key = ENV['ELEVENLABS_API_KEY']
    return ServiceResult.new(success: false, errors: ["ElevenLabs API key missing"]) if api_key.blank?

    url = URI("#{BASE_URL}/text-to-speech/#{voice_id}")
    request = Net::HTTP::Post.new(url)
    request["xi-api-key"] = api_key
    request["Content-Type"] = "application/json"
    
    request.body = {
      text: text,
      model_id: DEFAULT_MODEL,
      voice_settings: {
        stability: settings[:stability] || 0.5,
        similarity_boost: settings[:similarity_boost] || 0.75,
        style: settings[:style] || 0.0,
        use_speaker_boost: settings[:use_speaker_boost].nil? ? true : settings[:use_speaker_boost]
      }
    }.to_json

    response = http_client(url).request(request)

    if response.is_a?(Net::HTTPSuccess)
      ServiceResult.new(success: true, data: Base64.strict_encode64(response.body))
    else
      data = JSON.parse(response.body) rescue {}
      detail = data["detail"]
      error_messages = if detail.is_a?(Hash)
                         detail.values.flatten
                       elsif detail.is_a?(Array)
                         detail
                       else
                         detail || data["message"] || "API Error #{response.code}"
                       end
      ServiceResult.new(success: false, errors: Array(error_messages), status: response.code.to_i)
    end
  end

  private

  def http_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE # Temporarily for dev
    http.read_timeout = 60 # Cloning/Synthesis can be slow
    http
  end

  def parse_response(response)
    data = JSON.parse(response.body) rescue {}
    if response.is_a?(Net::HTTPSuccess)
      ServiceResult.new(success: true, data: data)
    else
      detail = data["detail"]
      error_messages = if detail.is_a?(Hash)
                         detail.values.flatten
                       elsif detail.is_a?(Array)
                         detail
                       else
                         detail || data["message"] || "API Error #{response.code}"
                       end
      ServiceResult.new(success: false, errors: Array(error_messages), status: response.code.to_i)
    end
  end
end
