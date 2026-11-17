require 'rails_helper'

RSpec.describe 'V1::TicketGroups', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event_admin) do
    create(:user, :member).tap { |u| create(:event_assignment, role: :event_admin, event: event, user: u) }
  end
  let(:team_member) do
    create(:user, :member).tap { |u| create(:event_assignment, role: :event_team_member, event: event, user: u) }
  end
  let(:outsider) { create(:user, :member) }

  def headers_for(user) = { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  def json = JSON.parse(response.body)

  let!(:event) { create(:event, use_ticket_groups: true) }
  let(:base) { "/v1/events/#{event.id}/ticket_groups" }
  let(:type_a) { create(:ticket_type, event: event, name: 'A') }
  let(:type_b) { create(:ticket_type, event: event, name: 'B') }

  def paid_ticket(type, n)
    create(:ticket, event: event, ticket_type: type, status: :purchased, payment_status: :paid,
                    attendee_name: "T#{n}", attendee_email: "t#{n}@example.com")
  end

  describe 'access' do
    it 'needs a login' do
      get base
      expect(response).to have_http_status(:unauthorized)
    end

    it 'is blocked when the feature is off, even for the org owner' do
      event.update!(use_ticket_groups: false)
      get base, headers: headers_for(org_owner)
      expect(response).to have_http_status(:forbidden)
    end

    it 'keeps outsiders out' do
      get base, headers: headers_for(outsider)
      expect(response).to have_http_status(:forbidden)
    end

    it 'lets a team member look but not change' do
      get base, headers: headers_for(team_member)
      expect(response).to have_http_status(:ok)

      post "#{base}/setup", params: { count: 2 }, headers: headers_for(team_member), as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it 'lets the event admin manage' do
      post "#{base}/setup", params: { count: 2 }, headers: headers_for(event_admin), as: :json
      expect(response).to have_http_status(:ok)
    end

    it "does not let another event's groups be touched through this event" do
      other_group = create(:event, use_ticket_groups: true).ticket_groups.create!(name: 'X', position: 1)
      patch "#{base}/#{other_group.id}", params: { name: 'Hacked' }, headers: headers_for(org_owner), as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST setup' do
    it 'creates the number of groups asked, then adds more after' do
      post "#{base}/setup", params: { count: 3 }, headers: headers_for(org_owner), as: :json
      expect(json['groups'].map { |g| g['name'] }).to eq(['Group 1', 'Group 2', 'Group 3'])

      post "#{base}/setup", params: { count: 1 }, headers: headers_for(org_owner), as: :json
      expect(json['groups'].map { |g| g['position'] }).to eq([1, 2, 3, 4])
    end

    it 'rejects a count outside 1-20, or one that is not a number' do
      [0, 21, nil, [3], { 'a' => 1 }].each do |count|
        post "#{base}/setup", params: { count: count }, headers: headers_for(org_owner), as: :json
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH update and DELETE' do
    let!(:group) { event.ticket_groups.create!(name: 'Room A', position: 1) }

    it 'renames and sets ordered priority types' do
      patch "#{base}/#{group.id}", params: { name: 'Main Hall', priority_ticket_type_ids: [type_b.id, type_a.id] },
                                   headers: headers_for(org_owner), as: :json
      expect(response).to have_http_status(:ok)
      expect(json['groups'].first).to include('name' => 'Main Hall', 'priority_ticket_type_ids' => [type_b.id, type_a.id])
    end

    it "rejects another event's ticket type" do
      foreign = create(:ticket_type, event: create(:event), name: 'F')
      patch "#{base}/#{group.id}", params: { priority_ticket_type_ids: [foreign.id] }, headers: headers_for(org_owner), as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'deleting a group sends its tickets back to unassigned' do
      ticket = paid_ticket(type_a, 1)
      ticket.update_column(:ticket_group_id, group.id)

      delete "#{base}/#{group.id}", headers: headers_for(org_owner)
      expect(response).to have_http_status(:ok)
      expect(ticket.reload.ticket_group_id).to be_nil
      expect(json['unassigned_count']).to eq(1)
    end

    it 'drops a deleted ticket type from the priority lists' do
      group.update!(priority_ticket_type_ids: [type_a.id, type_b.id])
      type_a.destroy!
      expect(group.reload.priority_ticket_type_ids).to eq([type_b.id])
    end
  end

  describe 'preview, assign and move' do
    let!(:groups) { (1..2).map { |n| event.ticket_groups.create!(name: "Room #{n}", position: n) } }

    before { 4.times { |n| paid_ticket(type_a, n) } }

    it 'previews without saving' do
      post "#{base}/preview", params: { mode: 'new' }, headers: headers_for(org_owner), as: :json
      expect(response).to have_http_status(:ok)
      expect(json['groups'].map { |g| g['added'] }).to eq([2, 2])
      expect(Ticket.where(event_id: event.id).where.not(ticket_group_id: nil)).to be_empty
    end

    it 'assigns, balanced' do
      post "#{base}/assign", params: { mode: 'new' }, headers: headers_for(org_owner), as: :json
      expect(json['assigned']).to eq(4)
      expect(json['groups'].map { |g| g['ticket_count'] }).to eq([2, 2])
      expect(json['unassigned_count']).to eq(0)
    end

    it 'reports how many tickets of each type a group holds, and the unassigned ones' do
      paid_ticket(type_b, 50)
      ticket = paid_ticket(type_a, 51)
      ticket.update_column(:ticket_group_id, groups.first.id)

      get base, headers: headers_for(org_owner)
      first = json['groups'].find { |g| g['id'] == groups.first.id }
      expect(first['type_counts']).to eq(type_a.id.to_s => 1)
      expect(json['unassigned_by_type']).to eq(type_a.id.to_s => 4, type_b.id.to_s => 1)
    end

    it 'moves tickets by public id, to a group or to none' do
      ticket = paid_ticket(type_a, 99)

      patch "#{base}/move", params: { public_ids: [ticket.public_id], ticket_group_id: groups.last.id },
                            headers: headers_for(org_owner), as: :json
      expect(json['moved']).to eq(1)
      expect(ticket.reload.ticket_group_id).to eq(groups.last.id)

      patch "#{base}/move", params: { public_ids: [ticket.public_id], ticket_group_id: nil },
                            headers: headers_for(org_owner), as: :json
      expect(ticket.reload.ticket_group_id).to be_nil
    end

    it 'will not move a ticket into a group of another event' do
      other = create(:event, use_ticket_groups: true).ticket_groups.create!(name: 'X', position: 1)
      ticket = paid_ticket(type_a, 98)
      patch "#{base}/move", params: { public_ids: [ticket.public_id], ticket_group_id: other.id },
                            headers: headers_for(org_owner), as: :json
      expect(response).to have_http_status(:not_found)
      expect(ticket.reload.ticket_group_id).to be_nil
    end

    it 'treats a non-numeric group id (array, hash, SQL text) as not found, never as SQL' do
      ticket = paid_ticket(type_a, 97)
      ["1) OR (1=1", ['id = 1) OR (1=1'], { 'id' => '1' }].each do |bad|
        patch "#{base}/move", params: { public_ids: [ticket.public_id], ticket_group_id: bad },
                              headers: headers_for(org_owner), as: :json
        expect(response).to have_http_status(:not_found)
      end
      expect(ticket.reload.ticket_group_id).to be_nil
    end

    it 'will not move tickets of another event' do
      foreign_event = create(:event)
      foreign = create(:ticket, event: foreign_event, ticket_type: create(:ticket_type, event: foreign_event),
                                status: :purchased, payment_status: :paid, attendee_name: 'F', attendee_email: 'f@example.com')
      patch "#{base}/move", params: { public_ids: [foreign.public_id], ticket_group_id: groups.first.id },
                            headers: headers_for(org_owner), as: :json
      expect(json['moved']).to eq(0)
      expect(foreign.reload.ticket_group_id).to be_nil
    end
  end
end
