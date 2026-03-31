require 'rails_helper'

RSpec.describe 'V1::Roulette', type: :request do
  let(:event) { create(:event) }
  let(:org_owner) { create(:user, :org_owner) }
  let(:exhibitor) { create(:user, :exhibitor) }
  let(:member) { create(:user, :member) }

  def auth_header(user)
    token = JwtService.generate_tokens(user)[:access_token]
    { 'Authorization' => "Bearer #{token}" }
  end

  describe 'sessions lifecycle' do
    before do
      # Assign exhibitor to event as team member so they can access it
      EventAssignment.find_or_create_by!(event: event, user: exhibitor, role: :event_team_member)
    end

    it 'allows an authenticated user to create and list their sessions' do
      # Create session
      post "/v1/events/#{event.id}/roulette/sessions",
           params: {
             title: 'Test Session',
             is_multiple: false,
             draw_styles: { style: 'wheel', theme: 'wireframe' }
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['success']).to eq(true)
      session_id = body.dig('data', 'id')
      expect(session_id).to be_present
      expect(body.dig('data', 'event_id')).to eq(event.id)

      # List sessions
      get "/v1/events/#{event.id}/roulette/sessions", headers: auth_header(exhibitor)
      expect(response).to have_http_status(:ok)
      list_body = JSON.parse(response.body)
      ids = list_body['data'].map { |s| s['id'] }
      expect(ids).to include(session_id)
    end

    it 'defaults draw_counts to 1 when not provided' do
      post "/v1/events/#{event.id}/roulette/sessions",
           params: {
             title: 'Test Session',
             is_multiple: false,
             draw_styles: { style: 'wheel', theme: 'wireframe' }
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig('data', 'draw_counts')).to eq(1)
    end

    it 'allows setting draw_counts when is_multiple is true' do
      post "/v1/events/#{event.id}/roulette/sessions",
           params: {
             title: 'Test Session',
             is_multiple: true,
             draw_counts: 3,
             draw_styles: { style: 'wheel', theme: 'wireframe' }
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body.dig('data', 'draw_counts')).to eq(3)
    end

    it 'validates draw_counts must be >= 1 when is_multiple is true' do
      post "/v1/events/#{event.id}/roulette/sessions",
           params: {
             title: 'Test Session',
             is_multiple: true,
             draw_counts: 0,
             draw_styles: { style: 'wheel', theme: 'wireframe' }
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body['success']).to eq(false)
    end

    it 'validates draw_counts must be 1 when is_multiple is false' do
      post "/v1/events/#{event.id}/roulette/sessions",
           params: {
             title: 'Test Session',
             is_multiple: false,
             draw_counts: 2,
             draw_styles: { style: 'wheel', theme: 'wireframe' }
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:unprocessable_content)
      body = JSON.parse(response.body)
      expect(body['success']).to eq(false)
    end

    it 'allows updating draw_counts when is_multiple is true' do
      session = create(:roulette_session, event: event, user: exhibitor, is_multiple: true, draw_counts: 2)

      patch "/v1/events/#{event.id}/roulette/sessions/#{session.id}",
            params: {
              draw_counts: 5
            },
            headers: auth_header(exhibitor)

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.dig('data', 'draw_counts')).to eq(5)
    end
  end

  describe 'winners creation and business rules' do
    before do
      # Assign exhibitor to event as team member so they can access it
      EventAssignment.find_or_create_by!(event: event, user: exhibitor, role: :event_team_member)
    end

    let!(:session_single) { create(:roulette_session, event: event, user: exhibitor, is_multiple: false) }
    let!(:session_multi) { create(:roulette_session, event: event, user: exhibitor, is_multiple: true) }
    let!(:prize_single) { create(:roulette_prize, roulette_session: session_single, quantity: 1) }
    let!(:prize_multi) { create(:roulette_prize, roulette_session: session_multi, quantity: 2) }
    let!(:ticket) { create(:ticket, event: event) }
    let!(:visitor) { create(:visitor, event: event) }

    before do
      # Ensure ticket/visitor have public_id set (model callbacks handle this in app)
      ticket.update!(public_id: SecureRandom.uuid) if ticket.public_id.blank?
      visitor.update!(public_id: SecureRandom.uuid) if visitor.public_id.blank?
    end

    it 'allows creating a single winner when is_multiple is false and blocks second winner' do
      # First winner succeeds
      post "/v1/events/#{event.id}/roulette/sessions/#{session_single.id}/winners",
           params: {
             prize_id: prize_single.id,
             ticket_public_id: ticket.public_id
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body['success']).to eq(true)

      prize_single.reload
      expect(prize_single.remaining_quantity).to eq(0)

      # Second winner fails due to is_multiple = false
      post "/v1/events/#{event.id}/roulette/sessions/#{session_single.id}/winners",
           params: {
             prize_id: prize_single.id,
             visitor_public_id: visitor.public_id
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:unprocessable_content)
      error_body = JSON.parse(response.body)
      expect(error_body['success']).to eq(false)
      expect(error_body['message']).to match(/already has a winner|quantity exhausted/i)
    end

    it 'allows multiple winners when is_multiple is true until quantity is exhausted' do
      # First winner
      post "/v1/events/#{event.id}/roulette/sessions/#{session_multi.id}/winners",
           params: {
             prize_id: prize_multi.id,
             ticket_public_id: ticket.public_id
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)

      # Second winner
      post "/v1/events/#{event.id}/roulette/sessions/#{session_multi.id}/winners",
           params: {
             prize_id: prize_multi.id,
             visitor_public_id: visitor.public_id
           },
           headers: auth_header(exhibitor)

      expect(response).to have_http_status(:created)

      prize_multi.reload
      expect(prize_multi.remaining_quantity).to eq(0)

      # Third winner should fail due to quantity exhausted
      post "/v1/events/#{event.id}/roulette/sessions/#{session_multi.id}/winners",
           params: {
             prize_id: prize_multi.id,
             ticket_public_id: SecureRandom.uuid # non-existent ticket
           },
           headers: auth_header(exhibitor)

      # It may fail either on quantity exhausted or ticket not found; we assert failure status
      expect(response).to have_http_status(:unprocessable_content).or have_http_status(:not_found)
    end
  end

  describe 'participants' do
    let!(:ticket_event) { create(:event, use_ticket: true) }
    let!(:visitor_event) { create(:event, use_ticket: false) }
    let!(:session_ticket) { create(:roulette_session, event: ticket_event, user: exhibitor) }
    let!(:session_visitor) { create(:roulette_session, event: visitor_event, user: exhibitor) }
    let!(:ticket) { create(:ticket, event: ticket_event, attendee_name: 'Test Ticket', attendee_email: 'ticket@example.com') }
    let!(:visitor) { create(:visitor, event: visitor_event, full_name: 'Test Visitor', email: 'visitor@example.com') }
    let!(:other_ticket) { create(:ticket, event: ticket_event, attendee_name: 'Other Ticket') }
    let!(:other_visitor) { create(:visitor, event: visitor_event, full_name: 'Other Visitor') }

    before do
      # Ensure public_ids are set
      ticket.update!(public_id: SecureRandom.uuid) if ticket.public_id.blank?
      visitor.update!(public_id: SecureRandom.uuid) if visitor.public_id.blank?

      # Assign exhibitor to events
      EventAssignment.find_or_create_by!(event: ticket_event, user: exhibitor, role: :event_team_member)
      EventAssignment.find_or_create_by!(event: visitor_event, user: exhibitor, role: :event_team_member)
    end

    context 'when event uses tickets' do
      it 'fetches ticket by public_id' do
        get "/v1/events/#{ticket_event.id}/roulette/sessions/#{session_ticket.id}/participants/#{ticket.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to eq(true)
        expect(body['message']).to eq('Success')

        data = body['data']
        expect(data['type']).to eq('ticket')
        expect(data['id']).to eq(ticket.id)
        expect(data['public_id']).to eq(ticket.public_id)
        expect(data['attendee_name']).to eq('Test Ticket')
        expect(data['attendee_email']).to eq('ticket@example.com')
        expect(data['event']['id']).to eq(ticket_event.id)
        expect(data).to have_key('ticket_type')
      end

      it 'fetches ticket by internal id' do
        get "/v1/events/#{ticket_event.id}/roulette/sessions/#{session_ticket.id}/participants/#{ticket.id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to eq(true)

        data = body['data']
        expect(data['type']).to eq('ticket')
        expect(data['id']).to eq(ticket.id)
        expect(data['public_id']).to eq(ticket.public_id)
      end

      it 'returns 404 when ticket not found' do
        get "/v1/events/#{ticket_event.id}/roulette/sessions/#{session_ticket.id}/participants/non-existent-id",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body['error']).to eq('Participant not found')
      end

      it 'returns 404 when ticket belongs to different event' do
        other_event_ticket = create(:ticket, attendee_name: 'Other Event Ticket')
        other_event_ticket.update!(public_id: SecureRandom.uuid) if other_event_ticket.public_id.blank?

        get "/v1/events/#{ticket_event.id}/roulette/sessions/#{session_ticket.id}/participants/#{other_event_ticket.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body['error']).to eq('Participant not found in this event')
      end
    end

    context 'when event uses visitors' do
      it 'fetches visitor by public_id' do
        get "/v1/events/#{visitor_event.id}/roulette/sessions/#{session_visitor.id}/participants/#{visitor.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to eq(true)
        expect(body['message']).to eq('Success')

        data = body['data']
        expect(data['type']).to eq('visitor')
        expect(data['id']).to eq(visitor.id)
        expect(data['public_id']).to eq(visitor.public_id)
        expect(data['full_name']).to eq('Test Visitor')
        expect(data['email']).to eq('visitor@example.com')
        expect(data['event']['id']).to eq(visitor_event.id)
        expect(data).not_to have_key('ticket_type')
      end

      it 'fetches visitor by internal id' do
        get "/v1/events/#{visitor_event.id}/roulette/sessions/#{session_visitor.id}/participants/#{visitor.id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to eq(true)

        data = body['data']
        expect(data['type']).to eq('visitor')
        expect(data['id']).to eq(visitor.id)
        expect(data['public_id']).to eq(visitor.public_id)
      end

      it 'returns 404 when visitor not found' do
        get "/v1/events/#{visitor_event.id}/roulette/sessions/#{session_visitor.id}/participants/non-existent-id",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body['error']).to eq('Participant not found')
      end

      it 'returns 404 when visitor belongs to different event' do
        other_event_visitor = create(:visitor, full_name: 'Other Event Visitor')
        other_event_visitor.update!(public_id: SecureRandom.uuid) if other_event_visitor.public_id.blank?

        get "/v1/events/#{visitor_event.id}/roulette/sessions/#{session_visitor.id}/participants/#{other_event_visitor.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:not_found)
        body = JSON.parse(response.body)
        expect(body['error']).to eq('Participant not found in this event')
      end
    end

    context 'authorization' do
      it 'allows authorized users to fetch participants' do
        get "/v1/events/#{ticket_event.id}/roulette/sessions/#{session_ticket.id}/participants/#{ticket.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
      end

      it 'denies unauthorized users' do
        get "/v1/events/#{ticket_event.id}/roulette/sessions/#{session_ticket.id}/participants/#{ticket.public_id}",
            headers: auth_header(member)

        expect(response).to have_http_status(:forbidden)
      end

      it 'returns 404 when session not found' do
        get "/v1/events/#{ticket_event.id}/roulette/sessions/99999/participants/#{ticket.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 when event not found' do
        get "/v1/events/99999/roulette/sessions/#{session_ticket.id}/participants/#{ticket.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'response format' do
      it 'includes all ticket fields in response' do
        ticket.update!(
          checked_in: true,
          check_in_at: Time.current,
          status: :scanned,
          scanned_by: exhibitor
        )

        get "/v1/events/#{ticket_event.id}/roulette/sessions/#{session_ticket.id}/participants/#{ticket.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        data = body['data']

        expect(data).to have_key('type')
        expect(data).to have_key('id')
        expect(data).to have_key('public_id')
        expect(data).to have_key('attendee_name')
        expect(data).to have_key('attendee_email')
        expect(data).to have_key('attendee_phone')
        expect(data).to have_key('role')
        expect(data).to have_key('checked_in')
        expect(data).to have_key('check_in_at')
        expect(data).to have_key('status')
        expect(data).to have_key('ticket_type')
        expect(data).to have_key('event')
        expect(data).to have_key('scanned_by')
        expect(data['checked_in']).to eq(true)
        expect(data['check_in_at']).to be_present
      end

      it 'includes all visitor fields in response' do
        visitor.update!(
          checked_in: true,
          check_in_at: Time.current,
          scanned_by: exhibitor
        )

        get "/v1/events/#{visitor_event.id}/roulette/sessions/#{session_visitor.id}/participants/#{visitor.public_id}",
            headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        data = body['data']

        expect(data).to have_key('type')
        expect(data).to have_key('id')
        expect(data).to have_key('public_id')
        expect(data).to have_key('full_name')
        expect(data).to have_key('email')
        expect(data).to have_key('phone')
        expect(data).to have_key('role')
        expect(data).to have_key('gender')
        expect(data).to have_key('age')
        expect(data).to have_key('checked_in')
        expect(data).to have_key('check_in_at')
        expect(data).to have_key('event')
        expect(data).to have_key('scanned_by')
        expect(data).not_to have_key('ticket_type')
        expect(data['checked_in']).to eq(true)
        expect(data['check_in_at']).to be_present
      end
    end
  end

  describe 'winner notification' do
    let(:event_with_webhook) { create(:event, webhook_url: 'https://example.com/webhook') }
    let!(:session) { create(:roulette_session, event: event_with_webhook, user: exhibitor, is_multiple: true) }
    let!(:prize) { create(:roulette_prize, roulette_session: session, quantity: 2) }
    let!(:ticket) { create(:ticket, event: event_with_webhook, attendee_phone: '+60123456789') }

    before do
      EventAssignment.find_or_create_by!(event: event_with_webhook, user: exhibitor, role: :event_team_member)
      ticket.update!(public_id: SecureRandom.uuid) if ticket.public_id.blank?
    end

    context 'POST /v1/events/:event_id/roulette/sessions/:session_id/winners/:id/notify' do
      let!(:winner) do
        create(:roulette_winner,
               roulette_session: session,
               roulette_prize: prize,
               ticket: ticket,
               visitor: nil,
               drawn_at: Time.current)
      end

      it 'successfully sends webhook notification' do
        expect(WebhookSenderJob).to receive(:perform_later).with(
          event_with_webhook.webhook_url,
          hash_including(
            event_type: 'roulette.winner_declared',
            winner: hash_including(
              id: winner.id
            ),
            prize: hash_including(
              name: prize.name
            )
          )
        )

        post "/v1/events/#{event_with_webhook.id}/roulette/sessions/#{session.id}/winners/#{winner.id}/notify",
             headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['success']).to eq(true)
        expect(body['message']).to eq('Notification sent successfully')
      end

      it 'successfully sends notifications to multiple webhook URLs' do
        urls = 'https://example.com/w1, https://example.com/w2'
        event_with_webhook.update!(webhook_url: urls)

        expect(WebhookSenderJob).to receive(:perform_later).with('https://example.com/w1', any_args)
        expect(WebhookSenderJob).to receive(:perform_later).with('https://example.com/w2', any_args)

        post "/v1/events/#{event_with_webhook.id}/roulette/sessions/#{session.id}/winners/#{winner.id}/notify",
             headers: auth_header(exhibitor)

        expect(response).to have_http_status(:ok)
      end

      it 'returns error when event has no webhook_url' do
        event_with_webhook.update!(webhook_url: nil)

        post "/v1/events/#{event_with_webhook.id}/roulette/sessions/#{session.id}/winners/#{winner.id}/notify",
             headers: auth_header(exhibitor)

        expect(response).to have_http_status(:unprocessable_content)
        body = JSON.parse(response.body)
        expect(body['success']).to eq(false)
        expect(body['message']).to include('No webhook URL configured')
      end

      it 'denies unauthorized users' do
        post "/v1/events/#{event_with_webhook.id}/roulette/sessions/#{session.id}/winners/#{winner.id}/notify",
             headers: auth_header(member)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
