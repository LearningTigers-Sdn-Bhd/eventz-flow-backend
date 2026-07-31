# frozen_string_literal: true

class CustomsDeclarationAttacher
  Error = Class.new(StandardError)

  def initialize(event:, exhibitor_kit:, signed_id:)
    @event = event
    @exhibitor_kit = exhibitor_kit
    @signed_id = signed_id
  end

  def call
    return if @signed_id.blank?

    blob = ActiveStorage::Blob.find_signed(@signed_id.to_s)
    raise Error, 'Invalid or expired customs declaration upload' if blob.nil?
    unless blob.metadata['document_key'] == 'customs_declaration_form'
      raise Error, 'Uploaded file is not a customs declaration form'
    end
    raise Error, 'Customs declaration does not belong to this event' unless blob.metadata['event_id'].to_i == @event.id
    raise Error, 'Customs declaration upload was already used' if blob.attachments.exists?

    @exhibitor_kit.customs_declaration_form.attach(blob)
  end
end
