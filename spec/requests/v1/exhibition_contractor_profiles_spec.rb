require 'rails_helper'

RSpec.describe "V1::ExhibitionContractorProfiles", type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:contractor_user) { create(:user, :exhibition_contractor, created_by: org_owner) }
  let!(:contractor_profile) { create(:exhibition_contractor_profile, user: contractor_user) }

  describe "GET /v1/exhibition_contractor_profiles/:id" do
    context "as org_owner" do
      it "returns the profile" do
        get v1_exhibition_contractor_profile_path(contractor_profile), headers: auth_headers(org_owner)

        expect(response).to have_http_status(:ok)
        expect(json_body['id']).to eq(contractor_profile.id)
      end
    end

    context "as organizer" do
      it "returns the profile" do
        get v1_exhibition_contractor_profile_path(contractor_profile), headers: auth_headers(organizer)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as the contractor themselves" do
      it "returns their own profile" do
        get v1_exhibition_contractor_profile_path(contractor_profile), headers: auth_headers(contractor_user)

        expect(response).to have_http_status(:ok)
        expect(json_body['id']).to eq(contractor_profile.id)
      end
    end

    context "with non-existing profile" do
      it "returns not found" do
        get v1_exhibition_contractor_profile_path(0), headers: auth_headers(org_owner)

        expect(response).to have_http_status(:not_found)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        get v1_exhibition_contractor_profile_path(contractor_profile)

  describe "POST /v1/exhibition_contractor_profiles" do
    let(:user_for_profile) { create(:user, :exhibition_contractor, with_profile: false) }
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
        expect(response).to have_http_status(:unprocessable_content)
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
    let(:update_params) { { exhibition_contractor_profile: { company_name: "Updated Company" } } }

    context "as org_owner" do
      it "updates the profile" do
        patch v1_exhibition_contractor_profile_path(contractor_profile), params: update_params, headers: auth_headers(org_owner)

        expect(response).to have_http_status(:ok)
        expect(contractor_profile.reload.company_name).to eq("Updated Company")
      end
    end

    context "as organizer who created the contractor" do
      let(:contractor_by_organizer) { create(:user, :exhibition_contractor, created_by: organizer) }
      let!(:profile_by_organizer) { create(:exhibition_contractor_profile, user: contractor_by_organizer) }

      it "updates the profile" do
        patch v1_exhibition_contractor_profile_path(profile_by_organizer), params: update_params, headers: auth_headers(organizer)

        expect(response).to have_http_status(:ok)
        expect(profile_by_organizer.reload.company_name).to eq("Updated Company")
      end
    end

    context "as the contractor themselves" do
      it "updates their own profile" do
        patch v1_exhibition_contractor_profile_path(contractor_profile), params: update_params, headers: auth_headers(contractor_user)

        expect(response).to have_http_status(:ok)
        expect(contractor_profile.reload.company_name).to eq("Updated Company")
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        patch v1_exhibition_contractor_profile_path(contractor_profile), params: update_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

def json_body
  JSON.parse(response.body)
end
