# frozen_string_literal: true

# One-off cleanup: strip the "(Host: ...)" suffix that the seeder used to
# append to Business Matching session titles (e.g. "Synergy Health
# Matchmaking (Host: Jessica Rodriguez)" -> "Synergy Health Matchmaking").
#
# To run: bundle exec rails runner db/fix_business_matching_titles.rb

puts "--- Removing '(Host: ...)' suffix from Business Matching session titles ---"

pattern = /\s*\(Host:.*?\)\s*\z/

updated = 0
BusinessMatchingSession.find_each do |session|
  next unless session.title.match?(pattern)

  old_title = session.title
  new_title = session.title.sub(pattern, "").strip
  session.update!(title: new_title)
  updated += 1
  puts "  \"#{old_title}\" -> \"#{new_title}\""
end

puts "Updated #{updated} session title(s)."
