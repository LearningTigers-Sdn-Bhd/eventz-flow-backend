require 'rails_helper'

RSpec.describe "V1::Visitors Edge Cases", type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:event) { create(:event, title: 'Edge Case Event') }
  let(:token) { JwtService.generate_tokens(organizer)[:access_token] }
  let(:headers) { { 'Authorization' => "Bearer #{token}", 'Content-Type' => 'application/json' } }

  before do
    EventAssignment.create!(event: event, user: organizer, role: :event_admin)
  end

  describe "POST /v1/events/:event_id/visitors" do
    context "when custom_fields_data is sent as a stringified JSON" do
      let(:params) do
        {
          visitor: {
            full_name: "Stringy Json",
            # Simulate what happens with some multipart forms or automation tools
            custom_fields_data: "{\"Location\": \"Remote\", \"Source\": \"Zapier\"}"
          }
        }
      end

      it "parses the string and saves the custom fields" do
        post "/v1/events/#{event.id}/visitors", params: params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['full_name']).to eq("Stringy Json")
        expect(json['custom_fields_data']).to be_present
        expect(json['custom_fields_data']['Location']).to eq("Remote")
        expect(json['custom_fields_data']['Source']).to eq("Zapier")
      end
    end

    context "when custom_fields_data is sent as a malformed string" do
      let(:params) do
        {
          visitor: {
            full_name: "Malformed Json",
            custom_fields_data: "{BadJson"
          }
        }
      end

      it "ignores the malformed string and creates the visitor without custom fields" do
        post "/v1/events/#{event.id}/visitors", params: params.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['full_name']).to eq("Malformed Json")
        # Should be empty or nil depending on DB default, usually empty hash from serializer
        expect(json['custom_fields_data']).to eq({})
      end
    end
  end
end
