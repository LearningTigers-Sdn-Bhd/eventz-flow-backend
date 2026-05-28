namespace :exhibitor do
  desc 'Backfill company name into exhibitor team member tickets missing the company custom field'
  task backfill_team_member_company: :environment do
    scope = ExhibitorTeamMember
      .where(attendee_type: 'Ticket')
      .joins(:exhibitor_kit)
      .where.not(exhibitor_kits: { company_name: [nil, ''] })

    total = scope.count
    puts "Found #{total} team members with a ticket and a company name"

    updated = 0
    skipped = 0

    scope.find_each do |member|
      ticket = member.attendee
      next skipped += 1 if ticket.nil?
      next skipped += 1 if ticket.custom_fields_data&.key?('company')

      ExhibitorTeamMemberAttendeeSyncService.new(member).call
      updated += 1
      print '.'
    end

    puts "\nDone. Updated: #{updated}, Skipped: #{skipped}"
  end
end
