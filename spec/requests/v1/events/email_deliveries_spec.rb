require 'rails_helper'

RSpec.describe 'V1::Events::EmailDeliveries', type: :request do
  let(:event) { create(:event) }
  let(:admin) { create(:user, :organizer) }
  let(:headers) { auth_headers(admin) }
  let(:base) { "/v1/events/#{event.id}/email_deliveries" }

  before { create(:event_assignment, event: event, user: admin, role: :event_admin) }

  def rows
    JSON.parse(response.body)['data']
  end

  describe 'GET index' do
    it 'lists only this event and hides provider internals' do
      ticket = create(:ticket, event: event, attendee_name: 'Aini')
      mine = create(:email_delivery, :delivered, related: ticket, event_id: event.id)
      create(:email_delivery, :delivered, event_id: create(:event).id)

      get base, headers: headers

      expect(response).to have_http_status(:ok)
      expect(rows.map { |r| r['id'] }).to contain_exactly(mine.id)
      expect(rows.first['attendee']).to eq('ticket_id' => ticket.id, 'name' => 'Aini')
      expect(rows.first.keys).not_to include('provider', 'provider_message_id', 'metadata', 'last_error')
    end

    it 'filters by outcome group' do
      create(:email_delivery, :delivered, event_id: event.id)
      bounced = create(:email_delivery, :sent, status: 'bounced', bounced_at: Time.current, event_id: event.id)

      get base, params: { status_group: 'problem' }, headers: headers

      expect(rows.map { |r| r['id'] }).to contain_exactly(bounced.id)
    end

    it 'filters by email type' do
      create(:email_delivery, :delivered, event_id: event.id, mailer_action: 'confirmation_email')
      invite = create(:email_delivery, :delivered, event_id: event.id, mailer_action: 'host_invitation_email')

      get base, params: { email_type: 'host_invitation_email' }, headers: headers

      expect(rows.map { |r| r['id'] }).to contain_exactly(invite.id)
    end

    it 'hides a row once it has been retried' do
      original = create(:email_delivery, :failed, event_id: event.id)
      retry_row = create(:email_delivery, :sent, event_id: event.id, resend_of: original)

      get base, headers: headers

      expect(rows.map { |r| r['id'] }).to contain_exactly(retry_row.id)
    end

    it 'rejects an admin of a different event' do
      other = create(:user, :organizer)
      create(:event_assignment, event: create(:event), user: other, role: :event_admin)

      get base, headers: auth_headers(other)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET summary' do
    it 'counts per outcome group' do
      create(:email_delivery, :delivered, event_id: event.id)
      create(:email_delivery, :failed, event_id: event.id)
      create(:email_delivery, :sent, status: 'bounced', event_id: event.id)

      get "#{base}/summary", headers: headers

      body = JSON.parse(response.body)
      expect(body['data']).to eq('delivered' => 1, 'sent' => 0, 'pending' => 0, 'problem' => 2)
      expect(body['email_types']).to eq(['confirmation_email'])
    end
  end

  describe 'GET export' do
    it 'downloads an Excel workbook of every email for the event' do
      create(:email_delivery, :failed, event_id: event.id)

      get "#{base}/export", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      expect(response.headers['Content-Disposition']).to include("email-status-event-#{event.id}.xlsx")
    end

    it 'rejects an admin of a different event' do
      other = create(:user, :organizer)
      create(:event_assignment, event: create(:event), user: other, role: :event_admin)

      get "#{base}/export", headers: auth_headers(other)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST resend' do
    let(:ticket) { create(:ticket, event: event, attendee_email: 'wrong@example.con') }
    let(:bounced) do
      create(:email_delivery, :sent, status: 'bounced', bounced_at: Time.current, related: ticket, event_id: event.id)
    end

    it 'corrects the ticket email then resends a bounced email' do
      post "#{base}/#{bounced.id}/resend", params: { email: 'right@example.com' }, headers: headers

      expect(response).to have_http_status(:accepted)
      expect(ticket.reload.attendee_email).to eq('right@example.com')
      expect(EmailDelivery.find_by(resend_of_id: bounced.id)).to be_present
    end

    it 'rejects an invalid corrected email' do
      post "#{base}/#{bounced.id}/resend", params: { email: 'nope' }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(ticket.reload.attendee_email).to eq('wrong@example.con')
    end

    it 'does not resend a delivered email' do
      delivered = create(:email_delivery, :delivered, related: ticket, event_id: event.id)

      post "#{base}/#{delivered.id}/resend", headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "cannot reach another event's delivery" do
      foreign = create(:email_delivery, :failed, event_id: create(:event).id)

      post "#{base}/#{foreign.id}/resend", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
