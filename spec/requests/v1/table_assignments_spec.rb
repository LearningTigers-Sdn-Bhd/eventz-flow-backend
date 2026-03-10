require 'rails_helper'

RSpec.describe "V1::TableAssignments", type: :request do
  let(:user) { create(:user) }
  let(:event) { create(:event) }
  let(:plan) { create(:plan, event: event) }
  let(:table) { create(:plan_object, :table, plan: plan) }
  let(:ticket) { create(:ticket, event: event) }
  let(:headers) { auth_headers(user) }

  describe "POST /v1/plans/:plan_id/assignments" do
    it "creates an assignment" do
      expect {
        post v1_plan_assignments_path(plan), params: { ticket_id: ticket.id, plan_object_id: table.id }, headers: headers
      }.to change(TableAssignment, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "fails if ticket is in another event" do
      other_ticket = create(:ticket) # different event
      post v1_plan_assignments_path(plan), params: { ticket_id: other_ticket.id, plan_object_id: table.id }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "blocks assignment with insufficient capacity payload" do
      full_table = create(:plan_object, :table, plan: plan, capacity: 1)
      create(:table_assignment, ticket: create(:ticket, event: event), plan_object: full_table)

      post v1_plan_assignments_path(plan), params: { ticket_id: ticket.id, plan_object_id: full_table.id }, headers: headers
      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("insufficient_space")
      expect(body["needed_to_fit"]).to eq(1)
    end
  end

  describe "PATCH /v1/assignments/:ticket_id" do
    let!(:assignment) { create(:table_assignment, ticket: ticket, plan_object: table, notes: nil) }

    it "updates assignment notes" do
      patch v1_assignment_path(ticket), params: { assignment: { notes: "Seat near exit" } }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(assignment.reload.notes).to eq("Seat near exit")
    end
  end

  describe "DELETE /v1/plans/:plan_id/assignments/:ticket_id" do
    before { create(:table_assignment, ticket: ticket, plan_object: table) }

    it "removes the assignment" do
      expect {
        delete v1_assignment_path(ticket), headers: headers
      }.to change(TableAssignment, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
