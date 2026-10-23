# frozen_string_literal: true

# ==============================================================================
# Script: Reassign Duplicate Business Matching Tables (Big Sabah Sale 2026)
# ==============================================================================
# Usage:
#   # Dry Run (Preview only, NO changes written):
#   bundle exec rails runner bin/reassign_duplicate_bm_tables.rb dry_run
#
#   # Execute Changes:
#   bundle exec rails runner bin/reassign_duplicate_bm_tables.rb apply
# ==============================================================================

mode = (ARGV[0] || ENV['MODE'] || 'dry_run').to_s.downcase
is_dry_run = mode != 'apply'

puts "========================================================"
puts is_dry_run ? " [DRY RUN MODE] - No database changes will be saved" : " [APPLY MODE] - Changes WILL be saved to database"
puts "========================================================"

event = Event.find_by(slug: 'big-sabah-sale-2026') || Event.find(31)
puts "==> Processing Event: #{event.title} (ID: #{event.id})"

sessions = event.business_matching_sessions.unarchived.order(:id)
puts "==> Total active sessions found: #{sessions.count}"

def parse_table_num(loc, title)
  return 8 if title.to_s.include?('JCScents')
  match = loc.to_s.scan(/\d+/).first
  match ? match.to_i : nil
end

# 1. Occupied tables
occupied = sessions.map { |s| parse_table_num(s.location, s.title) }.compact.uniq
max_table = [occupied.max || 101, 101].max

# 2. Pool of available tables: missing gaps first, then 102+
missing_gaps = ((1..max_table).to_a - occupied).sort
next_numbers = ((max_table + 1)..(max_table + 100)).to_a
available_pool = (missing_gaps + next_numbers) - occupied

puts "==> Current distinct occupied tables: #{occupied.size}"
puts "==> Missing gaps available to fill: #{missing_gaps.inspect}"
puts "==> Pool of upcoming tables: #{available_pool.first(10).inspect}..."

# 3. Group by table
by_table = Hash.new { |h, k| h[k] = [] }
sessions.each do |s|
  t = parse_table_num(s.location, s.title)
  by_table[t] << s if t
end

duplicates = by_table.select { |_tbl, list| list.size > 1 }

if duplicates.empty?
  puts "\n==> [OK] No duplicate tables found! All sessions already have unique tables."
  exit 0
end

puts "\n==> Found #{duplicates.size} duplicate table(s):"
planned_moves = []

duplicates.sort_by { |t, _| t }.each do |table_num, list|
  sorted = list.sort_by(&:id)
  keeper = sorted.first
  duplicates_to_move = sorted[1..-1]

  puts "\n--- Table #{table_num} (#{list.size} sellers) ---"
  puts "  [KEEP] Session ##{keeper.id}: '#{keeper.title}' (stays at Table #{table_num})"

  duplicates_to_move.each do |session|
    new_table_num = available_pool.shift
    new_location = "TABLE #{new_table_num}"
    planned_moves << { session: session, old_tbl: table_num, new_tbl: new_table_num, loc: new_location }

    if is_dry_run
      puts "  [WOULD MOVE] Session ##{session.id}: '#{session.title}' -> #{new_location}"
    else
      session.update!(location: new_location)
      puts "  [MOVED] Session ##{session.id}: '#{session.title}' -> #{new_location}"
    end
  end
end

puts "\n========================================================"
if is_dry_run
  puts " [DRY RUN COMPLETE] Total planned moves: #{planned_moves.size}"
  puts " To apply these changes, run with 'apply':"
  puts "   bundle exec rails runner bin/reassign_duplicate_bm_tables.rb apply"
else
  puts " [APPLY COMPLETE] Total moves executed: #{planned_moves.size}"
  refreshed_sessions = event.business_matching_sessions.unarchived.reload
  refreshed_by_table = Hash.new { |h, k| h[k] = [] }
  refreshed_sessions.each do |s|
    t = parse_table_num(s.location, s.title)
    refreshed_by_table[t] << s if t
  end
  puts " - Remaining duplicates: #{refreshed_by_table.select { |_t, l| l.size > 1 }.size}"
  puts " - Total distinct occupied tables: #{refreshed_by_table.keys.compact.size}"
end
puts "========================================================"
