require 'rails_helper'

RSpec.describe "V1::ExhibitionContractorProfiles", type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:api_key) { create(:api_key, user: org_owner) }
  let(:auth_header) { { 'Authorization' => api_key.raw_key } }

  describe "GET /v1/exhibition_contractor_profiles" do
    before { create_list(:exhibition_contractor_profile, 3) }

    context "with valid authorization" do
      before { get v1_exhibition_contractor_profiles_path, headers: auth_header }

      it "returns a successful response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns all exhibition contractor profiles" do
        expect(json_body.size).to eq(3)
      end
    end

    context "without authorization" do
      before { get v1_exhibition_contractor_profiles_path }

      it "returns unauthorized" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /v1/exhibition_contractor_profiles/:id" do
    let(:exhibition_contractor_profile) { create(:exhibition_contractor_profile) }

    context "with valid authorization and existing profile" do
      before { get v1_exhibition_contractor_profile_path(exhibition_contractor_profile), headers: auth_header }

      it "returns a successful response" do
        expect(response).to have_http_status(:ok)
      end

      it "returns the correct exhibition contractor profile" do
        expect(json_body['id']).to eq(exhibition_contractor_profile.id)
      end
    end

    context "with valid authorization and non-existing profile" do
      before { get v1_exhibition_contractor_profile_path(0), headers: auth_header } # Use 0 for non-existing ID

      it "returns not found" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authorization" do
      before { get v1_exhibition_contractor_profile_path(exhibition_contractor_profile) }

      it "returns unauthorized" do
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "POST /v1/exhibition_contractor_profiles" do
    let(:user_for_profile) { create(:user, :exhibition_contractor) }
    let(:valid_attributes) do
      {
        exhibition_contractor_profile: {
          user_id: user_for_profile.id,
          company_name: "New Company",
          contact_person: "New Contact",
          contact_email: "new@example.com",
          contact_phone: "111-222-3333"
        }
      }
    end

    context "with valid authorization and valid attributes" do
      it "creates a new exhibition contractor profile" do
        expect {
          post v1_exhibition_contractor_profiles_path, params: valid_attributes, headers: auth_header
        }.to change(ExhibitionContractorProfile, :count).by(1)
      end

      it "returns a created response" do
        post v1_exhibition_contractor_profiles_path, params: valid_attributes, headers: auth_header
        expect(response).to have_http_status(:created)
      end
    end

    context "with valid authorization and invalid attributes" do
      let(:invalid_attributes) { { exhibition_contractor_profile: { company_name: "" } } }

      it "does not create a profile" do
        expect {
          post v1_exhibition_contractor_profiles_path, params: invalid_attributes, headers: auth_header
        }.to_not change(ExhibitionContractorProfile, :count)
      end

      it "returns unprocessable entity" do
        post v1_exhibition_contractor_profiles_path, params: invalid_attributes, headers: auth_header
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        post v1_exhibition_contractor_profiles_path, params: valid_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /v1/exhibition_contractor_profiles/:id" do
    let(:exhibition_contractor_profile) { create(:exhibition_contractor_profile) }
    let(:new_attributes) { { exhibition_contractor_profile: { company_name: "Updated Company" } } }

    context "with valid authorization and valid attributes" do
      before { patch v1_exhibition_contractor_profile_path(exhibition_contractor_profile), params: new_attributes, headers: auth_header }

      it "updates the exhibition contractor profile" do
        exhibition_contractor_profile.reload
        expect(exhibition_contractor_profile.company_name).to eq("Updated Company")
      end

      it "returns a successful response" do
        expect(response).to have_http_status(:ok)
      end
    end

    context "with valid authorization and invalid attributes" do
      let(:invalid_attributes) { { exhibition_contractor_profile: { company_name: "" } } }

      it "does not update the profile" do
        patch v1_exhibition_contractor_profile_path(exhibition_contractor_profile), params: invalid_attributes, headers: auth_header
        exhibition_contractor_profile.reload
        expect(exhibition_contractor_profile.company_name).to_not eq("")
      end

      it "returns unprocessable entity" do
        patch v1_exhibition_contractor_profile_path(exhibition_contractor_profile), params: invalid_attributes, headers: auth_header
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "without authorization" do
      before { patch v1_exhibition_contractor_profile_path(exhibition_contractor_profile), params: new_attributes }

      it "returns unauthorized" do
        patch v1_exhibition_contractor_profile_path(exhibition_contractor_profile), params: new_attributes
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "DELETE /v1/exhibition_contractor_profiles/:id" do
    let!(:exhibition_contractor_profile) { create(:exhibition_contractor_profile) }

    context "with valid authorization" do
      it "deletes the exhibition contractor profile" do
        expect {
          delete v1_exhibition_contractor_profile_path(exhibition_contractor_profile), headers: auth_header
        }.to change(ExhibitionContractorProfile, :count).by(-1)
      end

      it "returns no content" do
        delete v1_exhibition_contractor_profile_path(exhibition_contractor_profile), headers: auth_header
        expect(response).to have_http_status(:no_content)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        delete v1_exhibition_contractor_profile_path(exhibition_contractor_profile)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

def json_body
  JSON.parse(response.body)
end