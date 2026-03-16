require 'rails_helper'

RSpec.describe ElevenLabsService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }
  let(:api_key) { 'test_api_key' }

  before do
    allow(ENV).to receive(:[]).with('ELEVENLABS_API_KEY').and_return(api_key)
  end

  describe '#add_voice' do
    let(:cloned_voice) do
      cv = create(:cloned_voice)
      cv.audio_samples.attach(
        io: StringIO.new("fake audio"),
        filename: 'test.wav',
        content_type: 'audio/wav'
      )
      cv
    end
    
    context 'when successful' do
      before do
        # Mock Active Storage download
        allow_any_instance_of(ActiveStorage::Blob).to receive(:download).and_return("audio data")
        
        stub_request(:post, "https://api.elevenlabs.io/v1/voices/add")
          .with(headers: { 'xi-api-key' => api_key })
          .to_return(status: 200, body: { voice_id: "new_voice_id" }.to_json)
      end

      it 'returns success with voice_id' do
        result = service.add_voice(cloned_voice)
        expect(result.success?).to be true
        expect(result.data["voice_id"]).to eq("new_voice_id")
      end
    end

    context 'when API returns error' do
      before do
        allow_any_instance_of(ActiveStorage::Blob).to receive(:download).and_return("audio data")

        stub_request(:post, "https://api.elevenlabs.io/v1/voices/add")
          .to_return(status: 400, body: { detail: { message: "Invalid sample" } }.to_json)
      end

      it 'returns failure with errors' do
        result = service.add_voice(cloned_voice)
        expect(result.success?).to be false
        expect(result.errors).to include("Invalid sample")
      end
    end
  end

  describe '#synthesize' do
    let(:text) { "Hello World" }
    let(:voice_id) { "test_voice_id" }

    context 'when successful' do
      before do
        stub_request(:post, "https://api.elevenlabs.io/v1/text-to-speech/#{voice_id}")
          .with(
            body: hash_including(
              text: text,
              model_id: "eleven_multilingual_v2"
            )
          )
          .to_return(status: 200, body: "audio_binary_content")
      end

      it 'returns base64 encoded audio' do
        result = service.synthesize(text, voice_id)
        expect(result.success?).to be true
        expect(result.data).to eq(Base64.strict_encode64("audio_binary_content"))
      end
    end

    context 'when credit limit exceeded' do
      before do
        stub_request(:post, "https://api.elevenlabs.io/v1/text-to-speech/#{voice_id}")
          .to_return(status: 401, body: { detail: { status: "insufficient_credits" } }.to_json)
      end

      it 'returns failure with status 401' do
        result = service.synthesize(text, voice_id)
        expect(result.success?).to be false
        expect(result.status).to eq(401)
      end
    end
  end
end
