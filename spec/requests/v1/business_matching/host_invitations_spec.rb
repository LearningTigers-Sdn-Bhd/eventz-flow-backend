require 'rails_helper'

RSpec.describe 'V1::BusinessMatching::HostInvitations', type: :request do
  let(:event) { create(:event, use_business_matching: true) }
  let(:admin) { create(:user, role: :organizer) }
  let(:session) do
    BusinessMatchingSession.create!(
      event: event, title: 'S', slot_duration: 30, start_time: '09:00', end_time: '17:00',
      start_date: Date.current, end_date: Date.current
    )
  end
  let(:path) { "/v1/business_matching/events/#{event.id}/host_invitations" }

  before { create(:event_assignment, event: event, user: admin, role: :event_admin) }

  it 'records the event on the delivery when an invite is sent' do
    post "/v1/business_matching/events/#{event.id}/hosts/send_invite_email",
         params: { business_matching_event_id: session.id.to_s, email: 'host@example.com' },
         headers: auth_headers(admin)

    delivery = EmailDelivery.find_by(mailer_action: 'host_invitation_email')
    expect(delivery).to have_attributes(event_id: event.id, related: session)
  end

  it 'lists only this event\'s host invitations with their status' do
    create(:email_delivery, :delivered, mailer_name: 'BookingMailer', mailer_action: 'host_invitation_email',
                                        recipient: 'a@example.com', event_id: event.id,
                                        metadata: { 'business_matching_event_id' => session.id.to_s })
    create(:email_delivery, mailer_name: 'BookingMailer', mailer_action: 'host_invitation_email',
                            recipient: 'other@example.com', event_id: create(:event).id)
    create(:email_delivery, recipient: 'ticket@example.com', event_id: event.id)

    get path, headers: auth_headers(admin)

    expect(response).to have_http_status(:ok)
    rows = json_response['data']
    expect(rows.map { |r| r['recipient'] }).to eq(['a@example.com'])
    expect(rows.first).to include('status' => 'delivered', 'business_matching_event_id' => session.id.to_s)
    expect(rows.first).not_to have_key('last_error')
  end

  it 'rejects users who cannot manage hosts' do
    get path, headers: auth_headers(create(:user))

    expect(response).to have_http_status(:forbidden)
  end
end
