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

  let(:base) { "/v1/events/#{event.id}/certificate_templates" }
  let(:field) do
    { id: 'f_name', type: 'attendee_name', label: 'Name', x: 200, y: 350,
      width: 700, height: 100, font_size: 48, font_style: 'bold', color: '#1A1A1A', align: 'center' }
  end

  describe 'GET /v1/events/:event_id/certificate_templates' do
    it 'returns an empty list when no template exists' do
      get base, headers: org_owner_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq([])
    end

    it 'lists every template of the event' do
      create(:certificate_template, event: event)
      create(:certificate_template, event: event, name: 'Jawatankuasa',
                                    ticket_type_ids: [create(:ticket_type, event: event).id])
      get base, headers: org_owner_headers
      expect(JSON.parse(response.body).map { |t| t['name'] }).to contain_exactly('Default', 'Jawatankuasa')
    end

    it 'forbids a non-admin user' do
      get base, headers: member_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'POST /v1/events/:event_id/certificate_templates' do
    let(:params) do
      { certificate_template: { orientation: 'landscape', canvas_width: 1123, canvas_height: 794, fields: [field] } }
    end

    it 'creates a template' do
      expect { post base, params: params, headers: org_owner_headers }.to change(CertificateTemplate, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it 'accepts a background image upload and returns its url' do
      post base, params: params.deep_merge(certificate_template: { background_image: png }), headers: org_owner_headers
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['background_image_url']).to be_present
    end

    it 'forbids a non-admin user' do
      post base, params: params, headers: member_headers
      expect(response).to have_http_status(:forbidden)
    end

    it 'assigns ticket types and rejects a second default template' do
      create(:certificate_template, event: event)
      ticket_type = create(:ticket_type, event: event)

      post base, params: { certificate_template: { name: 'Jawatankuasa', ticket_type_ids: [ticket_type.id] } },
                 headers: org_owner_headers
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)['ticket_type_ids']).to eq([ticket_type.id])

      expect {
        post base, params: { certificate_template: { name: 'Another default' } }, headers: org_owner_headers
      }.not_to change(CertificateTemplate, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a ticket type already used by another template' do
      ticket_type = create(:ticket_type, event: event)
      create(:certificate_template, event: event, ticket_type_ids: [ticket_type.id])

      post base, params: { certificate_template: { name: 'Dup', ticket_type_ids: [ticket_type.id] } },
                 headers: org_owner_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a ticket type from another event' do
      other = create(:ticket_type, event: create(:event))

      post base, params: { certificate_template: { name: 'X', ticket_type_ids: [other.id] } },
                 headers: org_owner_headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'duplicates design and background from another template' do
      source = create(:certificate_template, :ready, event: event)
      ticket_type = create(:ticket_type, event: event)

      post base, params: { duplicate_from_id: source.id,
                           certificate_template: { name: 'Jawatankuasa', ticket_type_ids: [ticket_type.id] } },
                 headers: org_owner_headers

      expect(response).to have_http_status(:created)
      copy = CertificateTemplate.find(JSON.parse(response.body)['id'])
      expect(copy.fields).to eq(source.fields)
      expect(copy.background_image).to be_attached
      expect(copy.background_image.blob).not_to eq(source.background_image.blob)
      expect(copy.status).to eq('draft')
    end
  end

  describe 'PATCH /v1/events/:event_id/certificate_templates/:id' do
    let!(:template) { create(:certificate_template, event: event) }

    it 'marks ready when background and fields are present in one request' do
      patch "#{base}/#{template.id}",
            params: { certificate_template: { status: 'ready', background_image: png, fields: [field] } },
            headers: org_owner_headers
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['status']).to eq('ready')
    end

    context 'removing the background image' do
      let!(:template) { create(:certificate_template, :ready, event: event) }

      it 'purges the image and downgrades a ready template to draft' do
        expect(template.background_image).to be_attached

        patch "#{base}/#{template.id}",
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

  describe 'DELETE /v1/events/:event_id/certificate_templates/:id' do
    it 'removes only that template' do
      keep = create(:certificate_template, event: event)
      drop = create(:certificate_template, event: event, ticket_type_ids: [create(:ticket_type, event: event).id])

      delete "#{base}/#{drop.id}", headers: org_owner_headers

      expect(response).to have_http_status(:no_content)
      expect(event.certificate_templates.reload).to eq([keep])
    end
  end
end
