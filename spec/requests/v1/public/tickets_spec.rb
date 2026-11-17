require 'rails_helper'

RSpec.describe 'V1::Public::Tickets', type: :request do
  let(:event) { create(:event, use_ticket_groups: true) }
  let(:ticket) { create(:ticket, :paid, event: event) }

  def fetch(ticket)
    get "/v1/public/events/#{event.slug}/tickets/#{ticket.public_id}"
    JSON.parse(response.body)['data']
  end

  describe 'GET /v1/public/events/:event_slug/tickets/:id' do
    it 'names the ticket group when the event uses groups' do
      group = event.ticket_groups.create!(name: 'Room B', position: 1)
      ticket.update_columns(ticket_group_id: group.id)

      data = fetch(ticket)

      expect(response).to have_http_status(:ok)
      expect(data['ticket_group']).to eq('id' => group.id, 'name' => 'Room B')
    end

    it 'sends null for a ticket without a group' do
      data = fetch(ticket)

      expect(data).to have_key('ticket_group')
      expect(data['ticket_group']).to be_nil
    end

    it 'leaves the key out when the event does not use groups' do
      event.update!(use_ticket_groups: false)

      expect(fetch(ticket)).not_to have_key('ticket_group')
    end
  end
end
