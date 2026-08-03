require 'rails_helper'

RSpec.describe 'V1::Public::RegistrationUploads', type: :request do
  let(:event) { create(:event, status: :published) }
  let(:file) { fixture_file_upload('test_image.png', 'image/jpeg') }

  describe 'POST /v1/public/events/:event_slug/registration_uploads' do
    it 'rejects when the event is not published' do
      draft_event = create(:event, status: :draft)

      post "/v1/public/events/#{draft_event.slug}/registration_uploads",
           params: { file: file, key: 'passport_copy' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to eq('Registration is not open for this event')
    end

    it 'rejects an unsupported document key' do
      post "/v1/public/events/#{event.slug}/registration_uploads",
           params: { file: file, key: 'malware' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to eq('Unsupported document type')
    end

    it 'rejects a missing file' do
      post "/v1/public/events/#{event.slug}/registration_uploads",
           params: { key: 'passport_copy' }

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to eq('File is required')
    end

    it 'rejects an unsupported content type' do
      bad_file = fixture_file_upload('test_image.png', 'text/html')

      post "/v1/public/events/#{event.slug}/registration_uploads",
           params: { file: bad_file, key: 'passport_copy' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects an oversize file' do
      allow_any_instance_of(V1::Public::RegistrationUploadsController)
        .to receive(:file_too_large?).and_return(true)

      post "/v1/public/events/#{event.slug}/registration_uploads",
           params: { file: file, key: 'passport_copy' }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'creates a blob with document metadata and returns its signed id' do
      post "/v1/public/events/#{event.slug}/registration_uploads",
           params: { file: file, key: 'passport_copy' }

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body)['data']
      expect(data['key']).to eq('passport_copy')
      expect(data['signed_id']).to be_present

      blob = ActiveStorage::Blob.find_signed(data['signed_id'])
      expect(blob.metadata['document_key']).to eq('passport_copy')
      expect(blob.metadata['event_id']).to eq(event.id)
      expect(blob.attachments).to be_empty
    end
  end
end
