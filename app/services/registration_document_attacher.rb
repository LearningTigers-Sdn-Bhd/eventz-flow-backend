# frozen_string_literal: true

# Resolves signed blob ids from a public registration payload and attaches
# them to the (unsaved) ticket. Attachment persists inside the same
# transaction as ticket.save, so a ticket never exists without its documents.
#
# Raises RegistrationDocumentAttacher::Error with a client-safe message when
# any attach rule fails.
class RegistrationDocumentAttacher
  Error = Class.new(StandardError)

  def initialize(event:, ticket:, documents:, replace_existing: false)
    @event = event
    @ticket = ticket
    @documents = documents.respond_to?(:to_unsafe_h) ? documents.to_unsafe_h : documents.to_h
    @replace_existing = replace_existing
  end

  def call
    @documents.each do |key, signed_id|
      key = key.to_s

      raise Error, "Unsupported document type: #{key}" unless Ticket::DOCUMENT_KEYS.include?(key)

      blob = ActiveStorage::Blob.find_signed(signed_id.to_s)
      raise Error, "Invalid or expired upload for #{key}" if blob.nil?

      unless blob.metadata['document_key'] == key
        raise Error, "Uploaded file does not match document type #{key}"
      end

      unless blob.metadata['event_id'].to_i == @event.id
        raise Error, "Upload for #{key} does not belong to this event"
      end

      # Always enforced, in both modes — replace_existing only exempts this
      # ticket's own prior attachment (handled below), never another ticket's.
      if blob.attachments.where.not(record: @ticket).exists?
        raise Error, "Upload for #{key} is already used by another registration"
      end

      existing_attachment = existing_attachment_for(key)
      next if existing_attachment&.blob_id == blob.id # re-submitting the same file: no-op, nothing to purge/attach

      existing_attachment.purge if @replace_existing && existing_attachment

      @ticket.registration_documents.attach(blob)
    end
  end

  private

  def existing_attachment_for(key)
    @ticket.registration_documents.find { |attachment| attachment.blob.metadata['document_key'] == key }
  end
end
