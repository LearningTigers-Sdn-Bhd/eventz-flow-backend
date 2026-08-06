require 'rails_helper'

RSpec.describe 'V1::Public::Registrations documents and dedupe', type: :request do
  let(:event) { create(:event, status: :published) }
  let!(:ticket_type) do
    create(:ticket_type, event: event, name: 'Driver', price: 100.00, status: :published, hidden: false)
  end

  def upload_blob(key:, event_id: event.id)
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('fake image bytes'),
      filename: "#{key}.jpg",
      content_type: 'image/jpeg',
      metadata: { document_key: key, event_id: event_id, uploaded_at: Time.current.iso8601 }
    )
  end

  def register(extra = {})
    post "/v1/public/events/#{event.slug}/register", params: {
      ticket_type_id: ticket_type.id,
      attendee_name: 'Ali Bin Ahmad',
      attendee_email: 'ali@example.com',
      attendee_phone: '+60123456789'
    }.merge(extra), as: :json
  end

  describe 'documents' do
    it 'attaches uploaded documents on registration' do
      blob = upload_blob(key: 'passport_copy')

      register(documents: { passport_copy: blob.signed_id })

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)['data']
      ticket = Ticket.find(data['ticket_id'])
      expect(ticket.registration_documents.count).to eq(1)
      expect(ticket.registration_documents.first.blob).to eq(blob)
      expect(data['documents'].first['key']).to eq('passport_copy')
    end

    it 'rejects an unknown document key' do
      blob = upload_blob(key: 'passport_copy')

      register(documents: { evil_key: blob.signed_id })

      expect(response).to have_http_status(:unprocessable_content)
      expect(Ticket.count).to eq(0)
    end

    it 'rejects a blob whose metadata key does not match the slot' do
      blob = upload_blob(key: 'photo_1')

      register(documents: { passport_copy: blob.signed_id })

      expect(response).to have_http_status(:unprocessable_content)
      expect(Ticket.count).to eq(0)
    end

    it 'rejects a blob already attached to another ticket' do
      blob = upload_blob(key: 'passport_copy')
      other = create(:ticket, event: event, ticket_type: ticket_type)
      other.registration_documents.attach(blob)

      register(documents: { passport_copy: blob.signed_id })

      expect(response).to have_http_status(:unprocessable_content)
      expect(event.tickets.count).to eq(1)
    end

    it 'rejects a blob uploaded for a different event' do
      blob = upload_blob(key: 'passport_copy', event_id: event.id + 999)

      register(documents: { passport_copy: blob.signed_id })

      expect(response).to have_http_status(:unprocessable_content)
      expect(Ticket.count).to eq(0)
    end
  end

  describe 'indemnity' do
    it 'writes _indemnity with a server-side signed_at' do
      register(indemnity: { accepted: true, method: 'esign', signed_name: 'Ali bin Ahmad' })

      expect(response).to have_http_status(:created)
      indemnity = Ticket.last.custom_fields_data['_indemnity']
      expect(indemnity['accepted']).to be true
      expect(indemnity['method']).to eq('esign')
      expect(indemnity['signed_name']).to eq('Ali bin Ahmad')
      expect(Time.iso8601(indemnity['signed_at'])).to be_within(1.minute).of(Time.current)
    end

    it 'strips a forged _indemnity from custom_fields_data' do
      register(custom_fields_data: { membership_no: 'A-1',
                                     _indemnity: { accepted: true, signed_at: '1999-01-01T00:00:00Z' } })

      expect(response).to have_http_status(:created)
      expect(Ticket.last.custom_fields_data).not_to have_key('_indemnity')
    end
  end

  describe 'terms agreement' do
    it 'writes a separate server-timestamped terms agreement with the acknowledgement name' do
      register(terms_agreement: {
        accepted: true,
        method: 'checkbox_typed_name',
        acknowledged_name: 'Ali Bin Ahmad',
        terms_version: 'borneo-safari-sabah-registration-terms-v1'
      })

      expect(response).to have_http_status(:created)
      agreement = Ticket.last.custom_fields_data['_terms_agreement']
      expect(agreement['accepted']).to be true
      expect(agreement['method']).to eq('checkbox_typed_name')
      expect(agreement['acknowledged_name']).to eq('Ali Bin Ahmad')
      expect(agreement['terms_version']).to eq('borneo-safari-sabah-registration-terms-v1')
      expect(Time.iso8601(agreement['accepted_at'])).to be_within(1.minute).of(Time.current)
      expect(Ticket.last.custom_fields_data).not_to have_key('_indemnity')
    end

    it 'rejects an incomplete terms agreement before creating a ticket' do
      register(terms_agreement: {
        accepted: true,
        method: 'checkbox_typed_name',
        terms_version: 'borneo-safari-sabah-registration-terms-v1'
      })

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors']).to include(a_string_matching(/full legal name/i))
      expect(Ticket.count).to eq(0)
    end

    it 'strips a forged _terms_agreement from custom_fields_data' do
      register(custom_fields_data: {
        membership_no: 'A-1',
        _terms_agreement: { accepted: true, accepted_at: '1999-01-01T00:00:00Z' }
      })

      expect(response).to have_http_status(:created)
      expect(Ticket.last.custom_fields_data).not_to have_key('_terms_agreement')
    end
  end

  describe 'field dedupe on register' do
    it 'returns 422 and creates no ticket for a duplicate membership_no' do
      create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'membership_no' => 'A-1234' })

      register(custom_fields_data: { membership_no: 'a-1234' }, attendee_email: 'second@example.com')

      expect(response).to have_http_status(:unprocessable_content)
      expect(event.tickets.count).to eq(1)
    end
  end

  describe 'GET /v1/public/events/:event_slug/field_availability' do
    it 'rejects a non-allowlisted key' do
      get "/v1/public/events/#{event.slug}/field_availability",
          params: { key: 'attendee_email', value: 'x@example.com' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to eq('Unsupported field key')
    end

    it 'reports a taken value case-insensitively' do
      create(:ticket, event: event, ticket_type: ticket_type, custom_fields_data: { 'membership_no' => 'A-1234' })

      get "/v1/public/events/#{event.slug}/field_availability",
          params: { key: 'membership_no', value: 'a-1234' }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)['data']['available']).to be false
    end

    it 'reports a free value as available' do
      get "/v1/public/events/#{event.slug}/field_availability",
          params: { key: 'membership_no', value: 'B-9999' }

      expect(JSON.parse(response.body)['data']['available']).to be true
    end
  end
end
