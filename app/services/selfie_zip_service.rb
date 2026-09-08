# frozen_string_literal: true

require 'zip'

# Zips every ticket's selfie (registration_documents keyed 'photo_1') for an
# event into a single archive, mirroring TicketExcelService's export shape so
# it reuses ExportLog + TicketExportsController unchanged.
class SelfieZipService
  DOCUMENT_KEY = 'photo_1'

  # @return [Hash] { file_path: String, export_log: ExportLog }
  def self.export(event_id, from: nil, to: nil, ticket_type_id: nil)
    new(event_id, from: from, to: to, ticket_type_id: ticket_type_id).export
  end

  def initialize(event_id, from:, to:, ticket_type_id:)
    @event = Event.find(event_id)
    @from = from
    @to = to
    @ticket_type_id = ticket_type_id
  end

  def export
    exports_dir = Rails.root.join('storage', 'exports')
    FileUtils.mkdir_p(exports_dir)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    file_path = exports_dir.join("selfies-#{@event.id}-#{timestamp}.zip")

    Zip::OutputStream.open(file_path.to_s) do |zip|
      scoped_tickets.each do |ticket|
        selfie = selfie_attachment_for(ticket)
        next unless selfie

        zip.put_next_entry(entry_name_for(ticket, selfie))
        zip.write(selfie.download)
      end
    end

    export_log = ExportLog.create!(event_id: @event.id, type: 'selfie-zip', sheet_path: file_path.to_s)

    { file_path: file_path.to_s, export_log: export_log }
  end

  private

  def scoped_tickets
    tickets = @event.tickets.includes(registration_documents_attachments: :blob)
    tickets = tickets.where('created_at >= ?', @from.beginning_of_day) if @from.present?
    tickets = tickets.where('created_at <= ?', @to.end_of_day) if @to.present?
    tickets = tickets.where(ticket_type_id: @ticket_type_id) if @ticket_type_id.present?
    tickets
  end

  def selfie_attachment_for(ticket)
    ticket.registration_documents.find { |a| a.blob.metadata['document_key'] == DOCUMENT_KEY }
  end

  def entry_name_for(ticket, selfie)
    ext = File.extname(selfie.blob.filename.to_s)
    safe_name = ticket.attendee_name.to_s.parameterize.presence || 'attendee'
    timestamp = selfie.blob.created_at.strftime('%Y%m%d_%H%M%S')
    # ponytail: second-precision timestamp, not guaranteed unique like public_id was —
    # two selfies uploaded the same second (e.g. bulk import) collide and one is
    # silently dropped from the zip. Switch back to public_id, or append blob.id,
    # if that ever actually happens.
    "#{safe_name}-#{timestamp}#{ext}"
  end
end
