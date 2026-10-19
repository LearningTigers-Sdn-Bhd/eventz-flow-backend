require 'rails_helper'

RSpec.describe 'V1::ExhibitorCertificates', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:member) { create(:user, :member) }
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" } }
  let(:member_headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(member)[:access_token]}" } }
  let!(:event) { create(:event) }

  def exhibitor_fields
    [{ 'id' => 'c', 'type' => 'company_name', 'x' => 100, 'y' => 300, 'width' => 800, 'height' => 100,
       'font_size' => 40, 'color' => '#000000', 'align' => 'center' },
     { 'id' => 'b', 'type' => 'booth_count', 'x' => 100, 'y' => 450, 'width' => 800, 'height' => 60,
       'font_size' => 20, 'color' => '#000000', 'align' => 'center' }]
  end

  def build_exhibitor(company:, payment_status: :paid, booking_status: :active, quantity: 1, email: 'pic@example.com')
    exhibitor = create(:exhibitor, event: event)
    create(:exhibitor_kit, event_vendor: exhibitor, company_name: company, pic_email_address: email,
                           payment_status: payment_status, booking_status: booking_status, booth_quantity: quantity)
    exhibitor
  end

  describe ExhibitorCertificate do
    it 'lists one certificate per company, only for live settled bookings, summing booths' do
      paid = build_exhibitor(company: 'Acme', quantity: 3)
      create(:exhibitor_kit, event_vendor: paid, company_name: 'Acme', booth_quantity: 2, payment_status: :waived)
      build_exhibitor(company: 'Unpaid Co', payment_status: :unpaid)
      build_exhibitor(company: 'Cancelled Co', booking_status: :cancelled)

      certs = described_class.for_event(event)
      expect(certs.map(&:company_name)).to eq(['Acme'])
      expect(certs.first.booth_count).to eq(5)
    end
  end

  describe 'template' do
    it 'allows one exhibitor template per event, separate from ticket templates' do
      create(:certificate_template, event: event)
      post "/v1/events/#{event.id}/certificate_templates?audience=exhibitor",
           params: { certificate_template: { name: 'Exhibitor', fields: exhibitor_fields } },
           headers: headers, as: :json
      expect(response).to have_http_status(:created)
      expect(event.reload.exhibitor_certificate_template).to be_present
      expect(event.certificate_templates.count).to eq(1)

      post "/v1/events/#{event.id}/certificate_templates?audience=exhibitor",
           params: { certificate_template: { name: 'Again', fields: [] } }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      get "/v1/events/#{event.id}/certificate_templates?audience=exhibitor", headers: headers
      expect(JSON.parse(response.body).size).to eq(1)
    end
  end

  describe 'GET index' do
    it 'returns eligible companies with delivery status' do
      build_exhibitor(company: 'Acme', quantity: 2)
      get "/v1/events/#{event.id}/exhibitor_certificates", headers: headers
      row = JSON.parse(response.body)['data'].first
      expect(row).to include('company_name' => 'Acme', 'booth_count' => 2, 'certificate_status' => nil)
    end

    it 'forbids a non-admin' do
      get "/v1/events/#{event.id}/exhibitor_certificates", headers: member_headers
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'sending' do
    let!(:template) do
      create(:certificate_template, :ready, event: event, audience: 'exhibitor', fields: exhibitor_fields)
    end
    let!(:exhibitor) { build_exhibitor(company: 'Acme') }

    it 'queues one email through send_one' do
      expect do
        post "/v1/events/#{event.id}/exhibitor_certificates/send_one",
             params: { exhibitor_id: exhibitor.id }, headers: headers
      end.to change(EmailDelivery, :count).by(1)
      expect(response).to have_http_status(:accepted)
    end

    it 'rejects an ineligible exhibitor' do
      other = build_exhibitor(company: 'Unpaid', payment_status: :unpaid)
      post "/v1/events/#{event.id}/exhibitor_certificates/send_one",
           params: { exhibitor_id: other.id }, headers: headers
      expect(response).to have_http_status(:not_found)
    end

    it 'send_batch skips companies already sent when skip_sent is on' do
      post "/v1/events/#{event.id}/exhibitor_certificates/send_batch", headers: headers
      expect(JSON.parse(response.body)['queued']).to eq(1)

      EmailDelivery.where(mailer_action: 'exhibitor_certificate_email').update_all(status: 'sent')
      post "/v1/events/#{event.id}/exhibitor_certificates/send_batch",
           params: { skip_sent: true }, headers: headers
      expect(JSON.parse(response.body)['queued']).to eq(0)
    end

    it 'refuses to send when the template is not ready' do
      template.update_columns(status: CertificateTemplate.statuses[:draft])
      post "/v1/events/#{event.id}/exhibitor_certificates/send_batch", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'renders preview and download_all as PDFs' do
      get "/v1/events/#{event.id}/exhibitor_certificates/preview", headers: headers
      expect(response.media_type).to eq('application/pdf')
      get "/v1/events/#{event.id}/exhibitor_certificates/download_all", headers: headers
      expect(response.media_type).to eq('application/pdf')
    end

    it 'attaches a PDF in the mailer' do
      mail = CertificateMailer.exhibitor_certificate_email(exhibitor)
      expect(mail.to).to eq(['pic@example.com'])
      expect(mail.attachments['certificate.pdf']).to be_present
      expect(mail.body.encoded).to include('Acme')
    end
  end
end
