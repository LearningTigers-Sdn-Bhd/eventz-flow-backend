# frozen_string_literal: true

class CustomsDutyEstimateAttacher
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
    raise Error, 'Invalid or expired customs duty estimate upload' if blob.nil?
    unless blob.metadata['document_key'] == 'customs_duty_estimate'
      raise Error, 'Uploaded file is not a customs duty estimate'
    end
    raise Error, 'Customs duty estimate does not belong to this event' unless blob.metadata['event_id'].to_i == @event.id
    raise Error, 'Customs duty estimate upload was already used' if !@allow_reuse && blob.attachments.exists?

    @exhibitor_kit.customs_duty_estimate.attach(blob)
  end
end
