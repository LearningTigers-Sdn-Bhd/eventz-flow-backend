require 'rails_helper'

RSpec.describe "V1::EventExhibitionContractors", type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:api_key) { create(:api_key, user: org_owner) }
  let(:auth_header) { { 'Authorization' => api_key.raw_key } }

  let(:event) { create(:event) }
  let(:exhibition_contractor_profile) { create(:exhibition_contractor_profile) }

  describe "GET /v1/events/:event_id/event_exhibition_contractor" do
    context "when an event exhibition contractor is assigned" do
      let!(:assigned_exhibition_contractor) { create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: exhibition_contractor_profile) }

      context "with valid authorization" do
        before { get v1_event_event_exhibition_contractor_path(event), headers: auth_header }

        it "returns a successful response" do
          expect(response).to have_http_status(:ok)
        end

        it "returns the event exhibition contractor for the event" do
          expect(json_body['id']).to eq(assigned_exhibition_contractor.id)
        end
      end

      context "without authorization" do
        before { get v1_event_event_exhibition_contractor_path(event) }

        it "returns unauthorized" do
          expect(response).to have_http_status(:unauthorized)
        end
      end
    end

    context "when no event exhibition contractor is assigned" do
      before { get v1_event_event_exhibition_contractor_path(event), headers: auth_header }

      it "returns a successful response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns a message indicating no contractor assigned" do
        expect(json_body['message']).to eq("No exhibition contractor assigned to this event")
      end
    end
  end

  describe "POST /v1/events/:event_id/event_exhibition_contractor" do
    let(:new_exhibition_contractor_profile) { create(:exhibition_contractor_profile) }
    let(:valid_attributes) do
      {
        event_exhibition_contractor: {
          exhibition_contractor_profile_id: new_exhibition_contractor_profile.id
        }
      }
    end

    context "with valid authorization and valid attributes" do
      it "creates a new event exhibition contractor" do
        expect {
          post v1_event_event_exhibition_contractor_path(event), params: valid_attributes, headers: auth_header
        }.to change(EventExhibitionContractor, :count).by(1)
      end

      it "returns a created response" do
        post v1_event_event_exhibition_contractor_path(event), params: valid_attributes, headers: auth_header
        expect(response).to have_http_status(:created)
      end
    end

    context "with valid authorization and invalid attributes (e.g., duplicate event_id)" do
      let(:new_profile_for_duplicate) { create(:exhibition_contractor_profile) }
      let(:invalid_attributes) do
        {
          event_exhibition_contractor: {
            exhibition_contractor_profile_id: new_profile_for_duplicate.id
          }
        }
      end

      it "does not create a duplicate event exhibition contractor" do
        create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: create(:exhibition_contractor_profile))
        expect {
          post v1_event_event_exhibition_contractor_path(event), params: invalid_attributes, headers: auth_header
        }.to_not change(EventExhibitionContractor, :count)
      end

      it "returns unprocessable entity" do
        create(:event_exhibition_contractor, event: event, exhibition_contractor_profile: create(:exhibition_contractor_profile))
        post v1_event_event_exhibition_contractor_path(event), params: invalid_attributes, headers: auth_header
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        post v1_event_event_exhibition_contractor_path(event), params: valid_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /v1/events/:event_id/event_exhibition_contractor" do
    let!(:event_exhibition_contractor_to_delete) { create(:event_exhibition_contractor, event: event) }

    context "with valid authorization" do
      it "deletes the event exhibition contractor" do
        expect {
          delete v1_event_event_exhibition_contractor_path(event), headers: auth_header
        }.to change(EventExhibitionContractor, :count).by(-1)
      end

      it "returns no content" do
        delete v1_event_event_exhibition_contractor_path(event), headers: auth_header
        expect(response).to have_http_status(:no_content)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        delete v1_event_event_exhibition_contractor_path(event)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

def json_body
  JSON.parse(response.body)
end
