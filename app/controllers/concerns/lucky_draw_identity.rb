module LuckyDrawIdentity
  extend ActiveSupport::Concern

  private

  def draw_identity(participant, winner: false)
    ticket = participant.is_a?(Ticket) ? participant : nil
    # shortcut: event 35 uses IC/passport labels; add an event setting when another event needs them.
    id_no = ticket && @event.id == 35 ? ticket.custom_fields_data&.fetch('ic_passport_no', nil).to_s.strip : nil
    clean = id_no.to_s.gsub(/[^\p{L}\p{N}]/, '')
    details = { contact: clean.present? ? "ID #{clean.last(6)}" : participant&.draw_contact }
    if winner
      @draw_identity_exhibitor = current_user.exhibitor_for?(@event) if @draw_identity_exhibitor.nil?
      unless @draw_identity_exhibitor
        details[:ticket_public_id] = ticket&.public_id
        details[:ic_passport_no] = id_no.presence
      end
    end
    details
  end
end
