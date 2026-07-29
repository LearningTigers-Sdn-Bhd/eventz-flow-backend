# frozen_string_literal: true

class ExhibitorIcCopyAttacher
  Error = Class.new(StandardError)

  def initialize(event:, exhibitor_kit:, signed_id:)
    @event = event
    @exhibitor_kit = exhibitor_kit
    @signed_id = signed_id
  end

  def call
    return if @signed_id.blank?

    blob = ActiveStorage::Blob.find_signed(@signed_id.to_s)
    raise Error, 'Invalid or expired IC copy upload' if blob.nil?
    raise Error, 'Uploaded file is not an IC copy' unless blob.metadata['document_key'] == 'exhibitor_ic_copy'
    raise Error, 'IC copy does not belong to this event' unless blob.metadata['event_id'].to_i == @event.id
    raise Error, 'IC copy upload was already used' if blob.attachments.exists?

    @exhibitor_kit.ic_copy.attach(blob)
  end
end
