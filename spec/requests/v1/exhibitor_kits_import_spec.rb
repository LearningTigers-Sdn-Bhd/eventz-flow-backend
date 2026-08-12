require 'rails_helper'
require 'caxlsx'

RSpec.describe 'Exhibitor kits import', type: :request do
  let(:organizer) { create(:user, role: :organizer) }
  let(:event) { create(:event, use_exhibitor_kit: true) }
  let(:headers) { { 'Authorization' => "Bearer #{jwt_token(organizer)}" } }

  describe 'GET /v1/events/:event_id/exhibitor_kits/import_template' do
    it 'returns a generated xlsx file' do
      get "/v1/events/#{event.id}/exhibitor_kits/import_template", headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end

    it 'rejects a non-organizer user' do
      other_user = create(:user, role: :vendor)
      get "/v1/events/#{event.id}/exhibitor_kits/import_template",
        headers: { 'Authorization' => "Bearer #{jwt_token(other_user)}" }

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /v1/events/:event_id/exhibitor_kits/import' do
    let(:zone) { create(:exhibitor_zone, event: event, zone: 'Hall A', quota: 10) }
    let!(:booth_price) do
      create(:exhibitor_booth_price, event: event, exhibitor_zone: zone,
        booth_type: 'Standard', label: 'Standard 3x3', price: 500, quota: 5)
    end

    def upload_with_row(row, content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
      package = Axlsx::Package.new
      package.workbook.add_worksheet(name: 'Exhibitors') do |sheet|
        sheet.add_row(ExhibitorKitImportTemplateService::FIXED_HEADERS)
        sheet.add_row(row)
      end
      file = Tempfile.new(['import', '.xlsx'])
      file.binmode
      package.serialize(file.path)
      file.rewind
      Rack::Test::UploadedFile.new(file.path, content_type)
    end

    it 'imports a valid row and returns created count' do
      file = upload_with_row([
        'reqspecvendor@example.com', 'Req Vendor', '0123456789', 'Acme', 'Addr',
        'Jane', '0198765432', '', 'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid'
      ])

      post "/v1/events/#{event.id}/exhibitor_kits/import", params: { file: file }, headers: headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body['created']['count']).to eq(1)
      expect(body['errors']['count']).to eq(0)
    end

    it 'rejects a non-organizer user' do
      other_user = create(:user, role: :vendor)
      file = upload_with_row([
        'unauthorized@example.com', 'Unauthorized', '0123456789', 'Acme', 'Addr',
        'Jane', '0198765432', '', 'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid'
      ])

      post "/v1/events/#{event.id}/exhibitor_kits/import", params: { file: file },
        headers: { 'Authorization' => "Bearer #{jwt_token(other_user)}" }

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns 422 when no file is provided' do
      post "/v1/events/#{event.id}/exhibitor_kits/import", params: {}, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 when the upload is not an xlsx file' do
      file = upload_with_row([
        'wrong-type@example.com', 'Wrong Type', '0123456789', 'Acme', 'Addr',
        'Jane', '0198765432', '', 'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid'
      ], content_type: 'text/plain')

      post "/v1/events/#{event.id}/exhibitor_kits/import", params: { file: file }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'returns 422 when the upload exceeds the size limit' do
      stub_const('V1::ExhibitorKitsController::MAX_IMPORT_FILE_SIZE', 1.byte)
      file = upload_with_row([
        'oversized@example.com', 'Oversized', '0123456789', 'Acme', 'Addr',
        'Jane', '0198765432', '', 'Standard', 'Hall A', 'Standard 3x3', nil, 1, 500, 'unpaid'
      ])

      post "/v1/events/#{event.id}/exhibitor_kits/import", params: { file: file }, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
