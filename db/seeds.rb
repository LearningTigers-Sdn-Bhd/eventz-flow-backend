# db/seeds.rb

# CRITICAL: Prevent destructive seeds from running in production
# This protects against:
# - Temporary database connections to empty/new databases during deployment
# - Database volume resets/recreations
# - Manual seed execution
# - Any future Rails behavior changes (db:prepare automatically running seeds)
if Rails.env.production? || Rails.env.staging?
  puts "=" * 80
  puts "🚫 ERROR: Seeds are DISABLED in production and staging environments!"
  puts "   This file contains destructive operations (delete_all) and should"
  puts "   only run in development environment."
  puts "   If you need to seed production/staging, do it manually with proper backups."
  puts "=" * 80
  exit(1)
end

require 'faker'

puts "-------------------- Starting High-Volume Database Seeding --------------------"

# --- Configuration & Cleanup ---
NUM_ORGANIZERS = 3
NUM_TEAM_MEMBERS = 3
NUM_EVENTS = 20
TICKETS_PER_EVENT = 10
BASE_DATE = Date.today + 1.week

# Destroying records in reverse dependency order to respect foreign key constraints
puts "Cleaning up existing records..."

# Use delete_all to bypass callbacks and foreign key constraints
# This is more efficient and avoids foreign key issues
ActiveRecord::Base.connection.disable_referential_integrity do
  Resource.delete_all
  ResourceTopic.delete_all
  ResourceCategory.delete_all
  ResourceMediaType.delete_all
  ResourceWritePermission.delete_all
  Ticket.delete_all
  EventLocationMember.delete_all
  EventAssignment.delete_all
  TicketType.delete_all
  EventLocation.delete_all
  Event.delete_all
  User.delete_all

  # Clean up the separate event admin/team member tables if they exist
  ActiveRecord::Base.connection.execute("DELETE FROM event_admins") if ActiveRecord::Base.connection.table_exists?('event_admins')
  ActiveRecord::Base.connection.execute("DELETE FROM event_team_members") if ActiveRecord::Base.connection.table_exists?('event_team_members')
end

puts "Cleaned up existing records."

# --- 1. USER GENERATION ---
puts "\n--- 1. Generating Users ---"

# A. Superadmin (org_owner)
superadmin = User.find_or_create_by!(email: 's@s.com') do |u|
  u.password = '12345678'
  u.role = :org_owner
  u.full_name = 'The Super System Owner'
  u.email_verified_at = Time.current
end
puts "Created Superadmin: #{superadmin.full_name}"

# B. Organizers (Will be used to create most events)
organizers = NUM_ORGANIZERS.times.map do |i|
  User.find_or_create_by!(email: "organizer_#{i+1}@example.com") do |u|
    u.password = '12345678'
    u.role = :organizer
    u.full_name = Faker::Name.name + " (Organizer #{i+1})"
    u.email_verified_at = Time.current
  end
end
puts "Created #{organizers.count} Organizers."

# C. Team Members (Staff who are not Admins)
team_members = NUM_TEAM_MEMBERS.times.map do |i|
  User.find_or_create_by!(email: "staff_#{i+1}@example.com") do |u|
    u.password = '12345678'
    u.role = :member
    u.full_name = Faker::Name.name + " (Staff #{i+1})"
    u.email_verified_at = Time.current
  end
end
puts "Created #{team_members.count} Team Members."

# D. Unauthorized Member (For testing 403 Forbidden)
unauthorized_member = User.find_or_create_by!(email: 'unauthorized@example.com') do |u|
  u.password = '12345678'
  u.role = :member
  u.full_name = 'Unauthorized Member'
  u.email_verified_at = Time.current
end

# E. Participant (For ticket ownership)
participant_user = User.find_or_create_by!(email: 'participant@example.com') do |u|
  u.password = '12345678'
  u.role = :member
  u.full_name = 'Sarah Ticket Holder'
  u.email_verified_at = Time.current
end
puts "Created participant user: #{participant_user.full_name}"

# F. Dedicated Vendor User
vendor_user = User.find_or_create_by!(email: 'vendor@example.com') do |u|
  u.password = '12345678'
  u.role = :vendor
  u.full_name = 'The Test Vendor'
  u.email_verified_at = Time.current
end
puts "Created Vendor User: #{vendor_user.full_name}"

# G. Dedicated Exhibition Contractor User
exhibition_contractor_user = User.find_or_create_by!(email: 'contractor@example.com') do |u|
  u.password = '12345678'
  u.role = :exhibition_contractor
  u.full_name = 'The Test Contractor'
  u.email_verified_at = Time.current
end
puts "Created Exhibition Contractor User: #{exhibition_contractor_user.full_name}"

# Combined users for easy random assignment
all_event_staff = organizers + team_members


# --- 2. GLOBAL TICKET TYPES (event_id = NULL) ---
puts "\n--- 2. Generating Global Ticket Types ---"

global_ticket_types = []

# Free Ticket Type
global_ticket_types << TicketType.find_or_create_by!(name: 'Community Pass', event_id: nil) do |tt|
  tt.price = 0.00
  tt.quantity = 10000
  tt.max_per_order = 2
  tt.status = :published
  tt.hidden = false
  tt.custom_fields_data = {
    description: 'Free admission for community members and students',
    requires_verification: true,
    valid_for: 'all_community_events'
  }
end

# Paid Ticket Types
global_ticket_types << TicketType.find_or_create_by!(name: 'Early Bird Access', event_id: nil) do |tt|
  tt.price = 35.00
  tt.quantity = 2000
  tt.max_per_order = 5
  tt.status = :published
  tt.hidden = false
  tt.custom_fields_data = {
    description: 'Limited time special pricing with exclusive early entry',
    benefits: ['Early entry', 'Priority seating', 'Welcome gift'],
    valid_until: (Date.today + 30.days).to_s
  }
end

global_ticket_types << TicketType.find_or_create_by!(name: 'VIP All-Access Pass', event_id: nil) do |tt|
  tt.price = 199.00
  tt.quantity = 500
  tt.max_per_order = 3
  tt.status = :published
  tt.hidden = false
  tt.custom_fields_data = {
    description: 'Premium experience with exclusive perks and amenities',
    benefits: ['All-access entry', 'VIP lounge access', 'Complimentary refreshments', 'Meet & greet opportunities', 'Premium parking'],
    tier: 'premium'
  }
end

puts "Created #{global_ticket_types.count} Global Ticket Types (event_id: NULL)."

# --- 3. EVENT GENERATION (Loop) ---
puts "\n--- 3. Generating #{NUM_EVENTS} Events ---"

all_events = NUM_EVENTS.times.map do |i|
  # Determine event status/payment status based on index for diversity
  event_status = i < 5 ? :draft : (i < 15 ? :published : :cancelled)
  payment_status = i.even? ? :paid : :unpaid # Roughly 50/50 paid/unpaid

  event = Event.create!(
    title: "#{Faker::Commerce.product_name} Expo #{i+1} (Status: #{event_status})",
    description: Faker::Lorem.paragraph(sentence_count: 2),
    status: event_status,
    payment_status: payment_status,
    start_date: BASE_DATE + i.days,
    end_date: BASE_DATE + i.days + 1.day,
    multiple_scans: i.even?, # Some events allow multiple scans
    published: event_status == :published
  )

  # Create event location(s)
  event_location = EventLocation.create!(
    event: event,
    name: Faker::Address.full_address, # Use 'name' for the location string
    scan_limit: 100,
    is_unlimited: i % 7 == 0
  )

  # Assign a random organizer as the EventAdmin using EventAssignment
  admin_user = organizers.sample
  EventAssignment.create!(event: event, user: admin_user, role: :event_admin)

  # Assign a random team member as staff for ~50% of the events
  if i.odd?
    team_member = team_members.sample
    EventAssignment.create!(event: event, user: team_member, role: :event_team_member)

    # Also assign this team member to the event location
    EventLocationMember.create!(event_location: event_location, member: team_member)
  end

  puts "  -> Event #{i+1}: #{event.title} (Admin: #{admin_user.full_name})"
  event
end

# --- 4. TICKET TYPE & TICKET GENERATION (Loop) ---
puts "\n--- 4. Generating Ticket Types and Tickets (Total: ~#{NUM_EVENTS * TICKETS_PER_EVENT} Tickets) ---"

all_events.each_with_index do |event, i|
  # Skip generating tickets for the first 3 events to simulate events without tickets
  next if i < 3

  # Create a couple of ticket types per event
  tt_ga = event.ticket_types.find_or_create_by!(name: 'General Admission') do |tt|
    tt.price = Faker::Commerce.price(range: 50.0..100.0)
    tt.quantity = 100
    tt.max_per_order = 5
    tt.status = :published
    tt.hidden = false
  end
  tt_vip = event.ticket_types.find_or_create_by!(name: 'VIP Pass') do |tt|
    tt.price = Faker::Commerce.price(range: 200.0..500.0)
    tt.quantity = 50
    tt.max_per_order = 2
    tt.status = :published
    tt.hidden = false
  end

  ticket_types = [tt_ga, tt_vip]

  # Generate tickets with varied statuses
  TICKETS_PER_EVENT.times do |j|

    # Cycle through statuses: purchased, scanned, refunded, canceled
    status = Ticket.statuses.keys[j % Ticket.statuses.keys.count]

    # Get the user who is an admin or team member for the event to simulate a scanner
    scanner = event.admins.sample || event.team_members.sample

    # Determine payment status (0: pending, 1: paid, 2: failed)
    payment_status = j.even? ? 1 : (j % 3 == 0 ? 2 : 0)

    ticket_attributes = {
      event: event,
      ticket_type: ticket_types.sample,
      user: participant_user, # Assign to our participant user (user_id is required)
      attendee_name: Faker::Name.name,
      attendee_email: Faker::Internet.email,
      attendee_phone: "+1#{rand(100..999)}-#{rand(100..999)}-#{rand(1000..9999)}",
      status: status,
      checked_in: status == 'scanned',
      scanned_by: status == 'scanned' ? scanner : nil,
      check_in_at: status == 'scanned' ? Time.current - rand(1..10).hours : nil,
      payment_status: payment_status
    }

    # Use Ticket.create! to ensure all models and validations are run
    Ticket.create!(ticket_attributes)
  end
end

puts "\n--- 5. Generating Resource CMS Data ---"

# Load professional resource content via rake task
Rake::Task['db:seed:resources'].invoke

puts "\n-------------------- Seeding Complete --------------------"
puts "Summary:"
puts "  Total Users: #{User.count}"
puts "  Total Events: #{Event.count}"
puts "  Total Ticket Types: #{TicketType.count} (#{TicketType.where(event_id: nil).count} global)"
puts "  Total Tickets: #{Ticket.count}"
puts "  Total Event Assignments: #{EventAssignment.count}"
puts "  Total Event Locations: #{EventLocation.count}"
puts "  Total Event Location Members: #{EventLocationMember.count}"
puts "  Total Resource Topics: #{ResourceTopic.count}"
puts "  Total Resource Categories: #{ResourceCategory.count}"
puts "  Total Resource Media Types: #{ResourceMediaType.count}"
puts "  Total Resource Write Permissions: #{ResourceWritePermission.count}"
puts "  Total Published Resources: #{Resource.where(status: :published).count}"
puts "\nLogin Credentials:"
puts "  Superadmin (Org Owner): s@s.com / 12345678"
puts "  Organizer 1: organizer_1@example.com / 12345678"
puts "  Team Member (Staff 1): staff_1@example.com / 12345678"
puts "  Participant: participant@example.com / 12345678"
