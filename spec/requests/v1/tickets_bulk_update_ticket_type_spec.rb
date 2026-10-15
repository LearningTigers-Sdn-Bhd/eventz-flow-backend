require 'rails_helper'

RSpec.describe 'V1::Tickets bulk update ticket type', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:team_member) { create(:user) }
  let(:event) { create(:event, payment_status: :paid) }
  let(:from_type) { create(:ticket_type, event: event) }
  let(:to_type) { create(:ticket_type, event: event) }
  let(:other_event_type) { create(:ticket_type) }
  let(:ticket_a) { create(:ticket, event: event, ticket_type: from_type) }
  let(:ticket_b) { create(:ticket, event: event, ticket_type: from_type) }

  before do
    EventAssignment.find_or_create_by!(event: event, user: team_member, role: :event_team_member)
  end

  describe 'PATCH /v1/events/:event_id/tickets/bulk_update_ticket_type' do
    it 'updates ticket_type_id for every ticket the user is authorized to update' do
      headers = auth_headers(org_owner)

      patch "/v1/events/#{event.id}/tickets/bulk_update_ticket_type",
            params: { ticket_type_id: to_type.id, ticket_ids: [ticket_a.public_id, ticket_b.public_id] },
            headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['updated']).to contain_exactly(ticket_a.public_id, ticket_b.public_id)
      expect(body['errors']).to be_empty
      expect(ticket_a.reload.ticket_type_id).to eq(to_type.id)
      expect(ticket_b.reload.ticket_type_id).to eq(to_type.id)
    end

    it 'rejects a ticket type that does not belong to the event' do
      headers = auth_headers(org_owner)

      patch "/v1/events/#{event.id}/tickets/bulk_update_ticket_type",
            params: { ticket_type_id: other_event_type.id, ticket_ids: [ticket_a.public_id] },
            headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(ticket_a.reload.ticket_type_id).to eq(from_type.id)
    end

    it 'ignores ticket ids that belong to a different event' do
      other_event = create(:event, payment_status: :paid)
      foreign_type = create(:ticket_type, event: other_event)
      foreign_ticket = create(:ticket, event: other_event, ticket_type: foreign_type)
      headers = auth_headers(team_member)

      patch "/v1/events/#{event.id}/tickets/bulk_update_ticket_type",
            params: { ticket_type_id: to_type.id, ticket_ids: [ticket_a.public_id, foreign_ticket.public_id] },
            headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['updated']).to contain_exactly(ticket_a.public_id)
      expect(ticket_a.reload.ticket_type_id).to eq(to_type.id)
      expect(foreign_ticket.reload.ticket_type_id).to eq(foreign_type.id)
    end
  end
end
