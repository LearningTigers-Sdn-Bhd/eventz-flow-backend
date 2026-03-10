require 'rails_helper'

RSpec.describe "V1::Plans", type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let!(:plan) { create(:plan, event: event) }
  let(:headers) { auth_headers(user) }

  describe "GET /v1/events/:event_id/plans" do
    it "returns list of plans" do
      get v1_event_plans_path(event), headers: headers
      puts "Debug Response: #{response.body}" unless response.ok?
      expect(response).to have_http_status(:ok)
      expect(json_response.size).to eq(1)
      expect(json_response.first['id']).to eq(plan.id)
    end
  end

  describe "GET /v1/plans/:id" do
    it "returns the plan with objects" do
      create(:plan_object, plan: plan)
      get v1_plan_path(plan), headers: headers
      expect(response).to have_http_status(:ok)
      expect(json_response['plan_objects'].size).to eq(1)
    end
  end

  describe "POST /v1/events/:event_id/plans" do
    let(:valid_attributes) { { name: 'New Plan', canvas_width: 800, canvas_height: 600 } }

    it "creates a new plan" do
      expect {
        post v1_event_plans_path(event), params: { plan: valid_attributes }, headers: headers
      }.to change(Plan, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "PATCH /v1/plans/:id" do
    let(:new_attributes) { { name: 'Updated Plan' } }

    it "updates the plan" do
      patch v1_plan_path(plan), params: { plan: new_attributes }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(plan.reload.name).to eq('Updated Plan')
    end
  end
end