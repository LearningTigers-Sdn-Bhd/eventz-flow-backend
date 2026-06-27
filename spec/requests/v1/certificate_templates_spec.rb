require 'rails_helper'

RSpec.describe 'V1::CertificateTemplates', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }

  let(:org_owner_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:member_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(member)[:access_token]}" } }

  let!(:event) { create(:event) }

  let(:png) do
    Rack::Test::UploadedFile.new(
      Rails.root.join('spec/fixtures/files/certificate_background.png'),
      'image/png'
    )
  end

  describe 'GET /v1/events/:event_id/certificate_template' do
    it 'returns null when no template exists' do
      get "/v1/events/#{event.id}/certificate_template", headers: org_owner_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to eq('null')
    end

    it 'returns the template when it exists' do
      create(:certificate_template, event: event)
      get "/v1/events/#{event.id}/certificate_template", headers: org_owner_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to include('orientation' => 'landscape')
    end

    it 'forbids a non-admin user' do
      get "/v1/events/#{event.id}/certificate_template", headers: member_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /v1/events/:event_id/certificate_template' do
    let(:params) do
      {
        certificate_template: {
          orientation: 'landscape',
          canvas_width: 1123,
          canvas_height: 794,
          fields: [
            { id: 'f_name', type: 'attendee_name', label: 'Name', x: 200, y: 350,
              width: 700, height: 100, font_size: 48, font_style: 'bold', color: '#1A1A1A', align: 'center' }
          ]
        }
      }
    end

    it 'creates a template' do
      expect {
        post "/v1/events/#{event.id}/certificate_template", params: params, headers: org_owner_headers
      }.to change(CertificateTemplate, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'accepts a background image upload and returns its url' do
      post "/v1/events/#{event.id}/certificate_template",
           params: params.deep_merge(certificate_template: { background_image: png }),
           headers: org_owner_headers
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['background_image_url']).to be_present
    end

    it 'forbids a non-admin user' do
      post "/v1/events/#{event.id}/certificate_template", params: params, headers: member_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'PATCH /v1/events/:event_id/certificate_template' do
    it 'marks ready when background and fields are present in one request' do
      patch "/v1/events/#{event.id}/certificate_template",
            params: {
              certificate_template: {
                status: 'ready',
                background_image: png,
                fields: [{ id: 'f_name', type: 'attendee_name', x: 1, y: 1, width: 10, height: 10, font_size: 12 }]
              }
            },
            headers: org_owner_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['status']).to eq('ready')
    end

    context 'removing the background image' do
      let!(:template) { create(:certificate_template, :ready, event: event) }

      it 'purges the image and downgrades a ready template to draft' do
        expect(template.background_image).to be_attached

        patch "/v1/events/#{event.id}/certificate_template",
              params: { certificate_template: { remove_background_image: true } },
              headers: org_owner_headers

        expect(response).to have_http_status(:ok)
        body = JSON.parse(response.body)
        expect(body['status']).to eq('draft')
        expect(body['background_image_url']).to be_nil
        expect(template.reload.background_image).not_to be_attached
      end
    end
  end
end
