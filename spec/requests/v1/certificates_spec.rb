require 'rails_helper'

RSpec.describe 'V1::Certificates', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:member) { create(:user, :member) }

  let(:org_owner_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:member_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(member)[:access_token]}" } }

  let!(:event) { create(:event) }

  describe 'POST /v1/events/:event_id/certificates/send_batch' do
    let!(:ticket) { create(:ticket, event: event, attendee_email: 'a@example.com') }
    let!(:ticket_no_email) { create(:ticket, event: event, attendee_email: nil) }

    context 'with a ready template' do
      let!(:template) { create(:certificate_template, :ready, event: event) }

      it 'queues sends and returns counts' do
        post "/v1/events/#{event.id}/certificates/send_batch",
             params: { audience: 'all' }, headers: org_owner_headers
        expect(response).to have_http_status(:accepted)
        body = JSON.parse(response.body)
        expect(body['queued']).to eq(1)
        expect(body['skipped_no_email']).to eq(1)
      end

      it 'forbids a non-admin user' do
        post "/v1/events/#{event.id}/certificates/send_batch",
             params: { audience: 'all' }, headers: member_headers
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'without a ready template' do
      let!(:template) { create(:certificate_template, event: event) } # draft

      it 'returns 422' do
        post "/v1/events/#{event.id}/certificates/send_batch",
             params: { audience: 'all' }, headers: org_owner_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET /v1/events/:event_id/certificates/preview' do
    context 'with a configured template' do
      let!(:template) { create(:certificate_template, :with_background, event: event) }

      it 'returns a PDF' do
        get "/v1/events/#{event.id}/certificates/preview", headers: org_owner_headers
        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/pdf')
        expect(response.body[0, 5]).to eq('%PDF-')
      end
    end

    context 'without a configured template' do
      it 'returns 422' do
        get "/v1/events/#{event.id}/certificates/preview", headers: org_owner_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'GET /v1/events/:event_id/certificates/participants' do
    let!(:template) { create(:certificate_template, :ready, event: event) }
    let!(:ticket) { create(:ticket, event: event, attendee_name: 'Alice', attendee_email: 'alice@example.com') }
    let!(:ticket_no_email) { create(:ticket, event: event, attendee_email: nil) }

    it 'lists participants with email, excluding email-less tickets' do
      get "/v1/events/#{event.id}/certificates/participants", headers: org_owner_headers
      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body)['data']
      expect(data.size).to eq(1)
      expect(data.first['attendee_name']).to eq('Alice')
      expect(data.first['certificate_status']).to be_nil
    end

    it 'reflects the latest certificate delivery status' do
      create(:email_delivery,
             related: ticket,
             mailer_name: 'CertificateMailer',
             mailer_action: 'certificate_email',
             status: 'sent',
             sent_at: Time.current)

      get "/v1/events/#{event.id}/certificates/participants", headers: org_owner_headers
      data = JSON.parse(response.body)['data']
      expect(data.first['certificate_status']).to eq('sent')
      expect(data.first['last_delivery_id']).to be_present
    end

    it 'forbids a non-admin user' do
      get "/v1/events/#{event.id}/certificates/participants", headers: member_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /v1/events/:event_id/certificates/download_all' do
    let!(:template) { create(:certificate_template, :ready, event: event) }
    let!(:ticket) { create(:ticket, event: event, attendee_email: 'a@example.com') }

    it 'returns a combined PDF' do
      get "/v1/events/#{event.id}/certificates/download_all",
          params: { audience: 'all' }, headers: org_owner_headers
      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include('application/pdf')
      expect(response.body[0, 5]).to eq('%PDF-')
    end

    it 'returns 422 when no attendees match' do
      get "/v1/events/#{event.id}/certificates/download_all",
          params: { audience: 'checked_in' }, headers: org_owner_headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'POST /v1/events/:event_id/certificates/send_one' do
    let!(:ticket) { create(:ticket, event: event, attendee_email: 'one@example.com') }

    context 'with a ready template' do
      let!(:template) { create(:certificate_template, :ready, event: event) }

      it 'queues a single certificate' do
        expect {
          post "/v1/events/#{event.id}/certificates/send_one",
               params: { public_id: ticket.public_id }, headers: org_owner_headers
        }.to have_enqueued_job(EmailDeliveryJob)
        expect(response).to have_http_status(:accepted)
      end

      it 'returns 404 for an unknown ticket' do
        post "/v1/events/#{event.id}/certificates/send_one",
             params: { public_id: 'does-not-exist' }, headers: org_owner_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'forbids a non-admin user' do
        post "/v1/events/#{event.id}/certificates/send_one",
             params: { public_id: ticket.public_id }, headers: member_headers
        expect(response).to have_http_status(:forbidden)
      end

      it 'rejects a waiting-list ticket without sending anything' do
        waiting_ticket = create(:ticket, event: event, attendee_email: 'waiting@example.com', waiting_list: true)

        expect {
          post "/v1/events/#{event.id}/certificates/send_one",
               params: { public_id: waiting_ticket.public_id }, headers: org_owner_headers
        }.not_to have_enqueued_job(EmailDeliveryJob)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'without a ready template' do
      let!(:template) { create(:certificate_template, event: event) } # draft

      it 'returns 422' do
        post "/v1/events/#{event.id}/certificates/send_one",
             params: { public_id: ticket.public_id }, headers: org_owner_headers
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end
end
