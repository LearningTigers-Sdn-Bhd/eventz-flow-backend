require 'rails_helper'

RSpec.describe "V1::PlanObjects", type: :request do
  let(:user) { create(:user) }
  let(:plan) { create(:plan) }
  let!(:plan_object) { create(:plan_object, plan: plan) }
  let(:headers) { auth_headers(user) }

  describe "POST /v1/plans/:plan_id/plan_objects" do
    let(:valid_attributes) { attributes_for(:plan_object, object_type: 'table', plan_id: plan.id) }

    it "creates a new object" do
      expect {
        post v1_plan_plan_objects_path(plan), params: { plan_object: valid_attributes }, headers: headers
      }.to change(PlanObject, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "PATCH /v1/plans/:plan_id/plan_objects/batch" do
    let(:obj1) { create(:plan_object, plan: plan, x: 10) }
    let(:obj2) { create(:plan_object, plan: plan, x: 20) }

    it "updates multiple objects" do
      batch_data = [
        { id: obj1.id, x: 15 },
        { id: obj2.id, x: 25 }
      ]
      patch batch_v1_plan_plan_objects_path(plan), params: { plan_objects: batch_data }, headers: headers
      
      expect(response).to have_http_status(:ok)
      expect(obj1.reload.x).to eq(15)
      expect(obj2.reload.x).to eq(25)
    end
  end

  describe "DELETE /v1/plans/:plan_id/plan_objects/:id" do
    it "destroys the object" do
      expect {
        delete v1_plan_object_path(plan_object), headers: headers
      }.to change(PlanObject, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end