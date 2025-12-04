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
