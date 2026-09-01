# frozen_string_literal: true

# Re-applies the exhibitor kit's current company name onto each team member's
# linked ticket. Company name is only pulled onto a ticket at the moment its
# member is created/synced (see ExhibitorTeamMemberAttendeeSyncService); if an
# admin fixes a typo on the kit afterward, already-issued tickets keep the
# stale value until someone edits them one by one. This is the bulk fix-up.
#
# Deliberately narrow: only touches custom_fields_data['company'], never
# status/payment_status/attendee fields — unlike the full attendee sync, this
# must be safe to run on tickets that have already been scanned or paid.
class ExhibitorTeamMemberCompanyResyncService
  def initialize(exhibitor_kit)
    @exhibitor_kit = exhibitor_kit
  end

  def call
    company_name = @exhibitor_kit.company_name.to_s.strip

    updated = []
    unchanged = []
    skipped = []
    failed = []

    @exhibitor_kit.exhibitor_team_members.includes(:attendee).order(:id).each do |member|
      ticket = member.attendee
      row = { id: member.id, full_name: member.full_name }

      if company_name.blank?
        skipped << row.merge(reason: 'Exhibitor kit has no company name set')
      elsif !ticket.is_a?(Ticket)
        skipped << row.merge(reason: 'No ticket linked yet')
      elsif ticket.custom_fields_data.to_h['company'].to_s == company_name
        unchanged << row
      elsif ticket.update(custom_fields_data: ticket.custom_fields_data.to_h.merge('company' => company_name))
        updated << row
      else
        failed << row.merge(reason: ticket.errors.full_messages.join(', '))
      end
    end

    { updated: updated, unchanged: unchanged, skipped: skipped, failed: failed }
  end
end
