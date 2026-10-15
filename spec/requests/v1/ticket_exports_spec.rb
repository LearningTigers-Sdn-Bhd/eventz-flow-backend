require 'rails_helper'

RSpec.describe 'V1::TicketExports', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:member) { create(:user, :member) }

  let(:org_owner_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:member_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(member)[:access_token]}" } }

  let!(:event) { create(:event) }
  let!(:ticket_type) { create(:ticket_type, event: event) }

  describe 'POST /v1/tickets/exports' do
    it 'defaults to a ticket-list Excel export' do
      post '/v1/tickets/exports', params: { event_id: event.id }, headers: org_owner_headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data']['type']).to eq('ticket-list')
    end

    it 'builds a selfie-zip export when type=selfie-zip' do
      post '/v1/tickets/exports', params: { event_id: event.id, type: 'selfie-zip' }, headers: org_owner_headers

      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['data']['type']).to eq('selfie-zip')
    end

    it 'forbids a non-admin user' do
      post '/v1/tickets/exports', params: { event_id: event.id, type: 'selfie-zip' }, headers: member_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /v1/tickets/exports' do
    it 'lists every export type by default, and filters when type is given' do
      ExportLog.create!(event_id: event.id, type: 'ticket-list', sheet_path: '/tmp/a.xlsx')
      ExportLog.create!(event_id: event.id, type: 'selfie-zip', sheet_path: '/tmp/b.zip')

      get '/v1/tickets/exports', params: { event_id: event.id }, headers: org_owner_headers
      expect(JSON.parse(response.body).size).to eq(2)

      get '/v1/tickets/exports', params: { event_id: event.id, type: 'selfie-zip' }, headers: org_owner_headers
      expect(JSON.parse(response.body).size).to eq(1)
      expect(JSON.parse(response.body).first['type']).to eq('selfie-zip')
    end
  end

  describe 'GET /v1/tickets/exports/:id' do
    it 'serves a zip export with the zip content type' do
      create(:ticket, event: event, ticket_type: ticket_type)
      export_log = SelfieZipService.export(event.id)[:export_log]

      get "/v1/tickets/exports/#{export_log.id}", headers: org_owner_headers

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/zip')
    end

    it 'still serves an xlsx export with the xlsx content type' do
      export_log = TicketExcelService.export(event.id)[:export_log]

      get "/v1/tickets/exports/#{export_log.id}", headers: org_owner_headers

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end
  end
end
