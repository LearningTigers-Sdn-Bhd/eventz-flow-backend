# frozen_string_literal: true

class IndemnityFormAttacher
  Error = Class.new(StandardError)

  def initialize(event:, exhibitor_kit:, signed_id:, allow_reuse: false)
    @event = event
    @exhibitor_kit = exhibitor_kit
    @signed_id = signed_id
    @allow_reuse = allow_reuse
  end

  def call
    return if @signed_id.blank?

    blob = ActiveStorage::Blob.find_signed(@signed_id.to_s)
    raise Error, 'Invalid or expired indemnity form upload' if blob.nil?
    raise Error, 'Uploaded file is not an indemnity form' unless blob.metadata['document_key'] == 'indemnity_form'
    raise Error, 'Indemnity form does not belong to this event' unless blob.metadata['event_id'].to_i == @event.id
    raise Error, 'Indemnity form upload was already used' if !@allow_reuse && blob.attachments.exists?

    @exhibitor_kit.indemnity_form.attach(blob)
  end
end
