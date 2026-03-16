class CloneVoiceJob < ApplicationJob
  queue_as :default

  def perform(cloned_voice_id)
    cloned_voice = ClonedVoice.find_by(id: cloned_voice_id)
    return unless cloned_voice

    service = ElevenLabsService.new(cloned_voice.creator)
    result = service.add_voice(cloned_voice)

    if result.success?
      cloned_voice.update!(
        elevenlabs_id: result.data["voice_id"],
        status: :ready
      )
      
      # Broadcast update
      broadcast_update(cloned_voice, { status: 'ready', voice_id: cloned_voice.elevenlabs_id })
      
      # Cleanup: Delete the audio samples now that they are in ElevenLabs
      cloned_voice.audio_samples.purge_later
    else
      cloned_voice.update!(status: :failed)
      broadcast_update(cloned_voice, { status: 'failed', errors: result.errors })
    end
  rescue StandardError => e
    cloned_voice&.update!(status: :failed)
    broadcast_update(cloned_voice, { status: 'failed', errors: [e.message] })
    raise e
  end

  private

  def broadcast_update(cloned_voice, data)
    payload = {
      type: 'voice_cloning_update',
      cloned_voice_id: cloned_voice.id,
      name: cloned_voice.name
    }.merge(data)

    # Broadcast to event-specific channel if present
    if cloned_voice.event_id
      ActionCable.server.broadcast("welcome_screen_event_#{cloned_voice.event_id}", payload)
    end

    # Broadcast to organization/group channel
    ActionCable.server.broadcast("user_voices_#{cloned_voice.owner_id}", payload)
  end
end
