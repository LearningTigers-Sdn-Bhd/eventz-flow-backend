require 'rails_helper'

RSpec.describe RegistrationDocumentAttacher do
  let(:event) { create(:event, status: :published) }
  let(:ticket_type) { create(:ticket_type, event: event) }
  let(:ticket) { create(:ticket, event: event, ticket_type: ticket_type) }

  def blob_for(key, event_id: event.id, bytes: 'file bytes')
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(bytes),
      filename: "#{key}.jpg",
      content_type: 'image/jpeg',
      metadata: { document_key: key, event_id: event_id, uploaded_at: Time.current.iso8601 }
    )
  end

  it 'attaches a new document to a ticket that has none yet' do
    blob = blob_for('passport_copy')

    described_class.new(event: event, ticket: ticket, documents: { passport_copy: blob.signed_id }).call

    expect(ticket.registration_documents.count).to eq(1)
    expect(ticket.registration_documents.first.blob).to eq(blob)
  end

  it 'raises when the blob is already attached to another ticket' do
    blob = blob_for('passport_copy')
    other_ticket = create(:ticket, event: event, ticket_type: ticket_type)
    other_ticket.registration_documents.attach(blob)

    expect {
      described_class.new(event: event, ticket: ticket, documents: { passport_copy: blob.signed_id }).call
    }.to raise_error(RegistrationDocumentAttacher::Error, /already used/)
  end

  context 'with replace_existing: true' do
    it "purges the ticket's own prior attachment for that key before attaching the new one" do
      old_blob = blob_for('passport_copy', bytes: 'old bytes')
      ticket.registration_documents.attach(old_blob)
      new_blob = blob_for('passport_copy', bytes: 'new bytes')

      described_class.new(
        event: event, ticket: ticket, documents: { passport_copy: new_blob.signed_id }, replace_existing: true
      ).call

      expect(ticket.registration_documents.count).to eq(1)
      expect(ticket.registration_documents.first.blob).to eq(new_blob)
    end

    it 'still attaches normally for a document key the ticket had nothing under' do
      blob = blob_for('photo_1')

      described_class.new(
        event: event, ticket: ticket, documents: { photo_1: blob.signed_id }, replace_existing: true
      ).call

      expect(ticket.registration_documents.count).to eq(1)
    end

    it "does not consider the ticket's own existing attachment 'already used by another registration'" do
      blob = blob_for('passport_copy')
      ticket.registration_documents.attach(blob)

      expect {
        described_class.new(
          event: event, ticket: ticket, documents: { passport_copy: blob.signed_id }, replace_existing: true
        ).call
      }.not_to raise_error
    end
  end
end
