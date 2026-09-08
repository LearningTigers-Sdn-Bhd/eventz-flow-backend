require 'rails_helper'
require 'zip'

RSpec.describe SelfieZipService do
  let(:event) { create(:event) }
  let(:general) { create(:ticket_type, event: event, name: 'General Admission') }
  let(:vip) { create(:ticket_type, event: event, name: 'VIP') }

  def selfie_blob(bytes: 'selfie bytes', key: 'photo_1')
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(bytes),
      filename: "#{key}.jpg",
      content_type: 'image/jpeg',
      metadata: { document_key: key, event_id: event.id, uploaded_at: Time.current.iso8601 }
    )
  end

  def entries_for(file_path)
    Zip::File.open(file_path) { |zip| zip.entries.map(&:name) }
  end

  describe '.export' do
    it 'zips only tickets that have a photo_1 selfie attached' do
      with_selfie = create(:ticket, event: event, ticket_type: general, attendee_name: 'Siti')
      blob = selfie_blob
      with_selfie.registration_documents.attach(blob)
      create(:ticket, event: event, ticket_type: general, attendee_name: 'No Selfie')

      result = described_class.export(event.id)

      expect(entries_for(result[:file_path])).to eq(["siti-#{blob.created_at.strftime('%Y%m%d_%H%M%S')}.jpg"])
    end

    it 'ignores non-selfie registration documents (e.g. passport_copy)' do
      ticket = create(:ticket, event: event, ticket_type: general, attendee_name: 'Ali')
      ticket.registration_documents.attach(selfie_blob(key: 'passport_copy'))

      result = described_class.export(event.id)

      expect(entries_for(result[:file_path])).to be_empty
    end

    it 'scopes to a single ticket type when ticket_type_id is given' do
      general_ticket = create(:ticket, event: event, ticket_type: general, attendee_name: 'General Person')
      general_ticket.registration_documents.attach(selfie_blob)
      vip_ticket = create(:ticket, event: event, ticket_type: vip, attendee_name: 'Vip Person')
      vip_blob = selfie_blob
      vip_ticket.registration_documents.attach(vip_blob)

      result = described_class.export(event.id, ticket_type_id: vip.id)

      expect(entries_for(result[:file_path])).to eq(["vip-person-#{vip_blob.created_at.strftime('%Y%m%d_%H%M%S')}.jpg"])
    end

    it 'names each entry by attendee name + selfie upload timestamp (second precision)' do
      ticket = create(:ticket, event: event, ticket_type: general, attendee_name: 'Bob Tan')
      blob = selfie_blob
      ticket.registration_documents.attach(blob)

      result = described_class.export(event.id)

      expect(entries_for(result[:file_path]).first).to match(/\Abob-tan-\d{8}_\d{6}\.jpg\z/)
    end

    it 'creates an ExportLog row of type selfie-zip' do
      result = described_class.export(event.id)

      expect(result[:export_log]).to have_attributes(event_id: event.id, type: 'selfie-zip', sheet_path: result[:file_path])
    end
  end
end
