require 'rails_helper'

RSpec.describe "V1::Tts", type: :request do
  let(:group) { create(:group) }
  let(:event) { create(:event) }
  let(:organizer) { create(:user, :organizer) }
  let(:event_admin) { create(:user, :member) }
  let(:regular_member) { create(:user, :member) }
  let(:cloned_voice) { create(:cloned_voice, :ready, owner: organizer, event: event, creator: organizer) }
  let(:voice_id) { cloned_voice.elevenlabs_id }

  before do
    # Assign roles
    create(:event_assignment, event: event, user: event_admin, role: :event_admin)
    
    # Ensure wallet has credits
    organizer.credit_wallet.add_credits!(100, :purchase, "Initial")
    
    # Mock ElevenLabs API Key safely
    stub_const('ENV', ENV.to_h.merge('ELEVENLABS_API_KEY' => 'test_key'))
    
    # Default mock for ElevenLabs synthesis
    stub_request(:post, /api.elevenlabs.io\/v1\/text-to-speech/)
      .to_return(status: 200, body: "audio_content")
  end

  describe "POST /v1/tts/synthesize" do
    let(:valid_params) do
      {
        text: "Welcome to the event!",
        voice_id: voice_id,
        event_id: event.id
      }
    end

    context "when authenticated as Group Manager" do
      it "synthesizes successfully and deducts credits" do
        expect {
          post "/v1/tts/synthesize", params: valid_params, headers: auth_headers(organizer)
        }.to change { organizer.credit_wallet.reload.balance }.by(-1)
        
        expect(response).to have_http_status(:ok)
        expect(json_response["success"]).to be true
        expect(json_response["audioContent"]).to be_present
      end
    end

    context "when authenticated as Event Admin" do
      before do
        # Mark voice as assigned to event in display settings
        create(:check_in_display, event: event, voice_type: voice_id)
      end

      it "synthesizes successfully" do
        post "/v1/tts/synthesize", params: valid_params, headers: auth_headers(event_admin)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when insufficient credits" do
      before do
        organizer.credit_wallet.update!(balance: 0)
      end

      it "returns payment_required status" do
        post "/v1/tts/synthesize", params: valid_params, headers: auth_headers(organizer)
        expect(response).to have_http_status(:payment_required)
        expect(json_response["message"]).to include("Insufficient credits")
      end
    end

    context "when unauthorized" do
      it "denies regular members" do
        post "/v1/tts/synthesize", params: valid_params, headers: auth_headers(regular_member)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with standard Google voice" do
      it "returns bad_request (handled by frontend or another proxy)" do
        post "/v1/tts/synthesize", 
             params: valid_params.merge(voice_id: "ms-MY-Wavenet-A"), 
             headers: auth_headers(organizer)
        expect(response).to have_http_status(:bad_request)
      end
    end
  end
end
