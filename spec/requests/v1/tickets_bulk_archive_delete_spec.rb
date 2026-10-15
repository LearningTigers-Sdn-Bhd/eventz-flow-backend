require 'rails_helper'

RSpec.describe 'V1::Tickets bulk archive/delete', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:team_member) { create(:user) }
  let(:event) { create(:event, payment_status: :paid) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:ticket_a) { create(:ticket, event: event, ticket_type: ticket_type) }
  let(:ticket_b) { create(:ticket, event: event, ticket_type: ticket_type) }

  before do
    EventAssignment.find_or_create_by!(event: event, user: team_member, role: :event_team_member)
  end

  describe 'PATCH /v1/events/:event_id/tickets/bulk_archive' do
    it 'allows org owner to soft-delete a batch of tickets' do
      headers = auth_headers(org_owner)

      patch "/v1/events/#{event.id}/tickets/bulk_archive",
            params: { ticket_ids: [ticket_a.public_id, ticket_b.public_id] },
            headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['archived']).to contain_exactly(ticket_a.public_id, ticket_b.public_id)
      expect(ticket_a.reload.deleted_at).to be_present
      expect(ticket_b.reload.deleted_at).to be_present
    end

    it 'allows organizer to soft-delete a batch of tickets' do
      headers = auth_headers(organizer)

      patch "/v1/events/#{event.id}/tickets/bulk_archive",
            params: { ticket_ids: [ticket_a.public_id] },
            headers: headers

      expect(response).to have_http_status(:ok)
      expect(ticket_a.reload.deleted_at).to be_present
    end

    it 'rejects a team member' do
      headers = auth_headers(team_member)

      patch "/v1/events/#{event.id}/tickets/bulk_archive",
            params: { ticket_ids: [ticket_a.public_id] },
            headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(ticket_a.reload.deleted_at).to be_nil
    end
  end

  describe 'DELETE /v1/events/:event_id/tickets/bulk_delete' do
    it 'allows org owner to permanently delete a batch of tickets' do
      headers = auth_headers(org_owner)
      ids = [ticket_a.public_id, ticket_b.public_id]

      delete "/v1/events/#{event.id}/tickets/bulk_delete",
             params: { ticket_ids: ids },
             headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body['deleted']).to contain_exactly(*ids)
      expect(Ticket.with_deleted.where(public_id: ids)).to be_empty
    end

    it 'rejects an organizer' do
      headers = auth_headers(organizer)

      delete "/v1/events/#{event.id}/tickets/bulk_delete",
             params: { ticket_ids: [ticket_a.public_id] },
             headers: headers

      expect(response).to have_http_status(:forbidden)
      expect(Ticket.with_deleted.where(public_id: ticket_a.public_id)).to exist
    end
  end
end
