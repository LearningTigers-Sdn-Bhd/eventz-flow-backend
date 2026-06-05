require "rails_helper"

RSpec.describe "V1::Plans AutoDistribute", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_headers(user) }
  let(:event) { create(:event) }
  let(:plan) { create(:plan, event: event) }
  let!(:table) { create(:plan_object, :table, plan: plan, capacity: 2) }

  it "returns skipped_groups for explicit groups that cannot fit" do
    group = create(:event_seating_group, event: event, plan: plan, name: "Large Group")
    tickets = create_list(:ticket, 3, event: event)
    tickets.each do |ticket|
      create(:event_seating_group_member, event_seating_group: group, participant: ticket)
    end

    post auto_distribute_v1_plan_path(plan), headers: headers
    expect(response).to have_http_status(:ok)

    body = JSON.parse(response.body)
    expect(body["skipped_groups"]).to be_an(Array)
    expect(body["skipped_groups"].first["group_id"]).to eq(group.id)
  end
end
