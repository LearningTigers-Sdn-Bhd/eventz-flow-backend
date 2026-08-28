namespace :tickets do
  desc 'Merge legacy "_table_number" custom field into the event\'s real "table_number" key'
  task backfill_table_number: :environment do
    scope = Ticket.where("custom_fields_data ? '_table_number'")

    total = scope.count
    puts "Found #{total} tickets with legacy _table_number field"

    updated = 0

    scope.find_each do |ticket|
      data = ticket.custom_fields_data || {}
      legacy_value = data['_table_number']
      key = data.keys.find { |k| k != '_table_number' && k.casecmp?('table_number') } || 'table_number'

      # Seating plan is authoritative once assigned, so the live value wins
      # over whatever the guest self-reported at registration.
      ticket.update_column(:custom_fields_data, data.except('_table_number').merge(key => legacy_value))
      updated += 1
      print '.'
    end

    puts "\nDone. Updated: #{updated}"
  end
end
