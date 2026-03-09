require "rails_helper"

RSpec.describe "V1::SeatingGroups", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:event) { create(:event) }
  let(:plan) { create(:plan, event: event) }

  describe "GET /v1/plans/:plan_id/seating_groups" do
    it "returns plan-only and event-level groups" do
      create(:event_seating_group, event: event, plan: plan, scope: :plan_only, name: "Plan Group")
      create(:event_seating_group, :event_level, event: event, name: "Event Group")

      get v1_plan_seating_groups_path(plan), headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      names = body.map { |g| g["name"] }
      expect(names).to include("Plan Group", "Event Group")
    end
  end

  describe "CRUD /v1/plans/:plan_id/seating_groups" do
    it "creates a plan-only group by default" do
      post v1_plan_seating_groups_path(plan), params: {
        seating_group: { name: "Family", notes: "VIP side" }
      }, headers: headers

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["scope"]).to eq("plan_only")
    end

    it "updates and deletes a group" do
      group = create(:event_seating_group, event: event, plan: plan)

      patch v1_plan_seating_group_path(plan, group), params: {
        seating_group: { name: "Renamed", scope: "event_level" }
      }, headers: headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["scope"]).to eq("event_level")

      expect {
        delete v1_plan_seating_group_path(plan, group), headers: headers
      }.to change(EventSeatingGroup, :count).by(-1)
    end
  end

  describe "members management" do
    let(:group) { create(:event_seating_group, event: event, plan: plan) }

    it "adds and removes a ticket member" do
      ticket = create(:ticket, event: event)
      post members_v1_plan_seating_group_path(plan, group), params: {
        participant_type: "Ticket",
        participant_id: ticket.id
      }, headers: headers

      expect(response).to have_http_status(:created)
      member_id = JSON.parse(response.body)["id"]

      delete member_v1_plan_seating_group_path(plan, group, member_id: member_id), headers: headers
      expect(response).to have_http_status(:no_content)
    end

    it "moves member between groups via add endpoint" do
      ticket = create(:ticket, event: event)
      other = create(:event_seating_group, event: event, plan: plan, name: "Other")
      create(:event_seating_group_member, event_seating_group: group, participant: ticket)

      post members_v1_plan_seating_group_path(plan, other), params: {
        participant_type: "Ticket",
        participant_id: ticket.id
      }, headers: headers

      expect(response).to have_http_status(:created)
      expect(ticket.reload.event_seating_group_member.event_seating_group_id).to eq(other.id)
    end
  end

  describe "POST /v1/plans/:plan_id/seating_groups/:id/assign_to_table" do
    let(:group) { create(:event_seating_group, event: event, plan: plan) }
    let(:table) { create(:plan_object, :table, plan: plan, capacity: 3) }

    it "assigns all members atomically when the table has enough seats" do
      tickets = create_list(:ticket, 2, event: event)
      tickets.each do |ticket|
        create(:event_seating_group_member, event_seating_group: group, participant: ticket)
      end

      post assign_to_table_v1_plan_seating_group_path(plan, group), params: { plan_object_id: table.id }, headers: headers

      expect(response).to have_http_status(:ok)
      expect(table.table_assignments.where(ticket_id: tickets.map(&:id)).count).to eq(2)
    end

    it "returns insufficient-space payload when group cannot fit" do
      full_table = create(:plan_object, :table, plan: plan, capacity: 1)
      create(:table_assignment, ticket: create(:ticket, event: event), plan_object: full_table)
      tickets = create_list(:ticket, 2, event: event)
      tickets.each do |ticket|
        create(:event_seating_group_member, event_seating_group: group, participant: ticket)
      end

      post assign_to_table_v1_plan_seating_group_path(plan, group), params: { plan_object_id: full_table.id }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
      body = JSON.parse(response.body)
      expect(body["error"]).to eq("insufficient_space")
      expect(body["needed_to_fit"]).to eq(2)
      expect(body["required_seats"]).to eq(2)
      expect(body["remaining_seats"]).to eq(0)
    end
  end
end
