require 'rails_helper'

RSpec.describe 'Exhibitor document attachers' do
  let(:event) { create(:event) }
  let(:first_kit) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event)) }
  let(:second_kit) { create(:exhibitor_kit, event_vendor: create(:exhibitor, event: event)) }

  [
    [ExhibitorIcCopyAttacher, :ic_copy, 'exhibitor_ic_copy'],
    [CustomsDeclarationAttacher, :customs_declaration_form, 'customs_declaration_form']
  ].each do |attacher, attachment, document_type|
    context attacher.name do
      let(:blob) do
        ActiveStorage::Blob.create_and_upload!(io: StringIO.new('document'), filename: 'document.pdf',
          content_type: 'application/pdf', metadata: { 'document_key' => document_type, 'event_id' => event.id })
      end

      it 'rejects a blob already attached to another kit by default' do
        first_kit.public_send(attachment).attach(blob)

        expect {
          attacher.new(event: event, exhibitor_kit: second_kit, signed_id: blob.signed_id).call
        }.to raise_error(attacher::Error, /already used/)
      end

      it 'allows the same blob within a batch when reuse is explicitly enabled' do
        first_kit.public_send(attachment).attach(blob)

        attacher.new(event: event, exhibitor_kit: second_kit, signed_id: blob.signed_id, allow_reuse: true).call

        expect(second_kit.public_send(attachment).blob).to eq(blob)
      end
    end
  end
end
