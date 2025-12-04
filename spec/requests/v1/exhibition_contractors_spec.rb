require 'rails_helper'

RSpec.describe "V1::ExhibitionContractors", type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }

  describe "GET /v1/exhibition_contractors" do
    let!(:contractor1) { create(:user, :exhibition_contractor, created_by: org_owner) }
    let!(:contractor2) { create(:user, :exhibition_contractor, created_by: organizer) }

    before do
      create(:exhibition_contractor_profile, user: contractor1)
      create(:exhibition_contractor_profile, user: contractor2)
    end

    context "as org_owner" do
      it "returns all contractors" do
        get v1_exhibition_contractors_path, headers: auth_headers(org_owner)

        expect(response).to have_http_status(:ok)
        expect(json_body.size).to eq(2)
      end
    end

    context "as organizer" do
      it "returns contractors created by them" do
        get v1_exhibition_contractors_path, headers: auth_headers(organizer)

        expect(response).to have_http_status(:ok)
        expect(json_body.size).to eq(1)
        expect(json_body.first['id']).to eq(contractor2.id)
      end
    end

    context "as member" do
      it "returns forbidden" do
        get v1_exhibition_contractors_path, headers: auth_headers(member)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        get v1_exhibition_contractors_path

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /v1/exhibition_contractors/:id" do
    let(:contractor) { create(:user, :exhibition_contractor, created_by: org_owner) }
    let!(:profile) { create(:exhibition_contractor_profile, user: contractor) }

    context "as org_owner" do
      it "returns the contractor with profile" do
        get v1_exhibition_contractor_path(contractor), headers: auth_headers(org_owner)

        expect(response).to have_http_status(:ok)
        expect(json_body['id']).to eq(contractor.id)
        expect(json_body['exhibition_contractor_profile']).to be_present
      end
    end

    context "as the contractor themselves" do
      it "returns their own data" do
        get v1_exhibition_contractor_path(contractor), headers: auth_headers(contractor)

        expect(response).to have_http_status(:ok)
        expect(json_body['id']).to eq(contractor.id)
      end
    end

    context "with non-existing contractor" do
      it "returns not found" do
        get v1_exhibition_contractor_path(0), headers: auth_headers(org_owner)

        expect(response).to have_http_status(:not_found)
      end
    end
  end


  describe "POST /v1/exhibition_contractors" do
    let(:valid_params) do
      {
        exhibition_contractor: {
          full_name: "John Contractor",
          email: "contractor@example.com",
          phone: "123-456-7890",
          password: "password123",
          password_confirmation: "password123",
          exhibition_contractor_profile_attributes: {
            company_name: "Contractor Co",
            contact_person: "John Doe",
            contact_email: "john@contractor.com",
            contact_phone: "987-654-3210"
          }
        }
      }
    end

    context "as org_owner" do
      before { org_owner } # ensure user is created before counting

      it "creates a contractor with profile" do
        expect {
          post v1_exhibition_contractors_path, params: valid_params, headers: auth_headers(org_owner)
        }.to change(User, :count).by(1).and change(ExhibitionContractorProfile, :count).by(1)

        expect(response).to have_http_status(:created)
        expect(json_body['role']).to eq('exhibition_contractor')
        expect(json_body['exhibition_contractor_profile']['company_name']).to eq("Contractor Co")
      end

      it "sets created_by to current user" do
        post v1_exhibition_contractors_path, params: valid_params, headers: auth_headers(org_owner)

        created_user = User.find(json_body['id'])
        expect(created_user.created_by_id).to eq(org_owner.id)
      end
    end

    context "as organizer" do
      before { organizer } # ensure user is created before counting

      it "creates a contractor" do
        expect {
          post v1_exhibition_contractors_path, params: valid_params, headers: auth_headers(organizer)
        }.to change(User, :count).by(1)

        expect(response).to have_http_status(:created)
      end
    end

    context "as member" do
      it "returns forbidden" do
        post v1_exhibition_contractors_path, params: valid_params, headers: auth_headers(member)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with invalid user params" do
      let(:invalid_params) do
        {
          exhibition_contractor: {
            full_name: "",
            email: "invalid",
            password: "123",
            password_confirmation: "456"
          }
        }
      end

      it "returns validation errors" do
        post v1_exhibition_contractors_path, params: invalid_params, headers: auth_headers(org_owner)

        expect(response).to have_http_status(:unprocessable_content)
        expect(json_body['errors']).to be_present
      end

      it "does not create user or profile" do
        org_owner # ensure user is created before counting
        expect {
          post v1_exhibition_contractors_path, params: invalid_params, headers: auth_headers(org_owner)
        }.to change(User, :count).by(0).and change(ExhibitionContractorProfile, :count).by(0)
      end
    end

    context "without authorization" do
      it "returns unauthorized" do
        post v1_exhibition_contractors_path, params: valid_params

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /v1/exhibition_contractors/:id" do
    let(:contractor) { create(:user, :exhibition_contractor, created_by: org_owner) }
    let!(:profile) { create(:exhibition_contractor_profile, user: contractor) }
    let(:update_params) do
      {
        exhibition_contractor: {
          full_name: "Updated Name",
          exhibition_contractor_profile_attributes: {
            company_name: "Updated Company"
          }
        }
      }
    end

    context "as org_owner" do
      it "updates the contractor and profile" do
        patch v1_exhibition_contractor_path(contractor), params: update_params, headers: auth_headers(org_owner)

        expect(response).to have_http_status(:ok)
        expect(contractor.reload.full_name).to eq("Updated Name")
        expect(profile.reload.company_name).to eq("Updated Company")
      end
    end

    context "as organizer who created the contractor" do
      let(:contractor_by_organizer) { create(:user, :exhibition_contractor, created_by: organizer) }
      let!(:profile_by_organizer) { create(:exhibition_contractor_profile, user: contractor_by_organizer) }

      it "updates the contractor" do
        patch v1_exhibition_contractor_path(contractor_by_organizer), params: update_params, headers: auth_headers(organizer)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as organizer who did not create the contractor" do
      it "returns forbidden" do
        patch v1_exhibition_contractor_path(contractor), params: update_params, headers: auth_headers(organizer)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /v1/exhibition_contractors/:id/toggle_status" do
    let(:contractor) { create(:user, :exhibition_contractor, created_by: org_owner, status: :active) }

    context "as org_owner" do
      it "toggles status to inactive" do
        patch toggle_status_v1_exhibition_contractor_path(contractor), params: { status: 'inactive' }, headers: auth_headers(org_owner)

        expect(response).to have_http_status(:ok)
        expect(contractor.reload.status).to eq('inactive')
      end
    end

    context "with invalid status" do
      it "returns error" do
        patch toggle_status_v1_exhibition_contractor_path(contractor), params: { status: 'invalid' }, headers: auth_headers(org_owner)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /v1/exhibition_contractors/:id" do
    let!(:contractor) { create(:user, :exhibition_contractor, created_by: org_owner) }
    let!(:profile) { create(:exhibition_contractor_profile, user: contractor) }

    context "as org_owner" do
      it "deletes the contractor" do
        expect {
          delete v1_exhibition_contractor_path(contractor), headers: auth_headers(org_owner)
        }.to change(User, :count).by(-1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "as organizer who created the contractor" do
      let!(:contractor_by_organizer) { create(:user, :exhibition_contractor, created_by: organizer) }

      it "deletes the contractor" do
        expect {
          delete v1_exhibition_contractor_path(contractor_by_organizer), headers: auth_headers(organizer)
        }.to change(User, :count).by(-1)
      end
    end

    context "as organizer who did not create the contractor" do
      it "returns forbidden" do
        delete v1_exhibition_contractor_path(contractor), headers: auth_headers(organizer)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "deleting self" do
      it "returns error" do
        delete v1_exhibition_contractor_path(contractor), headers: auth_headers(contractor)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end

def json_body
  JSON.parse(response.body)
end
