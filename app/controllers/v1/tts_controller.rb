module V1
  class TtsController < ApplicationController
    skip_before_action :authenticate_user!, only: [:synthesize]
    skip_before_action :require_verified_email!, only: [:synthesize]
    before_action :authenticate_user_if_token_present, only: [:synthesize]

    # POST /v1/tts/synthesize
    # Params: { text: "Hello", voice_id: "...", event_id: 123 }
    def synthesize
      text = params[:text]
      voice_id = params[:voice_id]
      event = Event.find(params[:event_id]) if params[:event_id]

      return error_response(message: "Text is required") if text.blank?
      return error_response(message: "Voice ID is required") if voice_id.blank?

      # 1. Determine Provider
      is_premium = !voice_id.start_with?("ms-MY-") && !voice_id.start_with?("en-US-")

      if is_premium
        handle_premium_synthesis(text, voice_id, event)
      else
        handle_standard_synthesis(text, voice_id)
      end
    end

    private

    def handle_premium_synthesis(text, voice_id, event)
      # Find the cloned voice to get its organization and settings
      cloned_voice = ClonedVoice.find_by(elevenlabs_id: voice_id)
      unless cloned_voice
        Rails.logger.error "[TTS] Voice not found: #{voice_id}"
        return error_response(message: "Voice not found", status: :not_found)
      end

      # 2. Permission Check
      # If authenticated, use standard rules. 
      # If NOT authenticated (Public Welcome Screen), allow ONLY if this voice is the one assigned to the event.
      is_authorized = if current_user
                        current_user.org_owner? || 
                        current_user.is_organizer? || 
                        (event && current_user.is_event_staff?(event)) ||
                        (event && event.check_in_display&.voice_type == voice_id)
                      else
                        # Public Access Rule
                        event && event.check_in_display&.voice_type == voice_id
                      end

      unless is_authorized
        Rails.logger.error "[TTS] Unauthorized access for voice #{voice_id} (Authenticated: #{!!current_user})"
        return error_response(message: "Not authorized to use this premium voice", status: :forbidden)
      end

      # 3. Credit Check
      # Pricing: 1 credit per 100 characters (rounded up)
      required_credits = (text.length / 100.0).ceil
      owner = cloned_voice.owner
      wallet = owner.credit_wallet

      if wallet.blank? || wallet.balance < required_credits
        available = wallet&.balance || 0
        Rails.logger.error "[TTS] Insufficient credits for owner #{owner.id}. Required: #{required_credits}, Available: #{available}"
        return error_response(message: "Insufficient credits. Required: #{required_credits}, Available: #{available}", status: :payment_required)
      end

      # 4. Call ElevenLabs
      # If no current_user (public), we use the voice owner as the context for the service
      service = ElevenLabsService.new(current_user || owner)
      
      # Use event-specific settings if available, otherwise fallback to voice defaults
      synthesis_settings = cloned_voice.settings.symbolize_keys
      if event&.check_in_display&.elevenlabs_settings.present?
        synthesis_settings = synthesis_settings.merge(event.check_in_display.elevenlabs_settings.symbolize_keys)
      end

      Rails.logger.info "[TTS] Calling ElevenLabs for voice #{voice_id}, text: #{text.truncate(50)}"
      result = service.synthesize(text, voice_id, synthesis_settings)

      if result.success?
        Rails.logger.info "[TTS] Synthesis successful for #{voice_id}"
        # 5. Deduct Credits
        wallet.deduct!(required_credits, "TTS Synthesis: #{text.truncate(20)}", { 
          voice_id: voice_id, 
          event_id: event&.id,
          char_count: text.length
        })

        # Log deduction for history
        CreditDeduction.create!(
          owner: owner,
          event: event,
          channel: 'tts',
          credits: required_credits,
          status: :sent,
          recipient: text.truncate(50)
        )

        render json: { success: true, audioContent: result.data }
      else
        Rails.logger.error "[TTS] ElevenLabs Error: #{result.errors.join(", ")}"
        error_response(message: result.errors.join(", "), status: :service_unavailable)
      end
    end

    def handle_standard_synthesis(text, voice_id)
      # Standard Google voices are free for now or handled by frontend directly if possible.
      # But for a "Secure Proxy" we might want to call Google TTS here too.
      # The plan says: "Update the synthesize API route to support ElevenLabs."
      # We'll return a 400 for now if they try to use this proxy for Google, 
      # or implement Google fallback if requested.
      render json: { 
        success: false, 
        message: "Standard voices should be handled via Google TTS directly or a separate proxy." 
      }, status: :bad_request
    end
  end
end
