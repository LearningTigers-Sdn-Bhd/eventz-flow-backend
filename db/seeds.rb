# db/seeds.rb
require 'faker'

puts "-------------------- Starting High-Volume Database Seeding --------------------"

# --- Configuration & Cleanup ---
NUM_MANAGERS = 3
NUM_TEAM_MEMBERS = 3
NUM_EVENTS = 20
TICKETS_PER_EVENT = 10
BASE_DATE = Date.today + 1.week

# Destroying records in reverse dependency order
[Ticket, EventLocation, EventTeamMember, EventAdmin, TicketType, Event, User].each(&:destroy_all)
puts "Cleaned up existing records."

# --- 1. USER GENERATION ---
puts "\n--- 1. Generating Users ---"

# A. Superadmin (org_owner)
superadmin = User.find_or_create_by!(email: 's@s.com') do |u|
  u.password = '12345678'
  u.role = :org_owner
  u.full_name = 'The Super System Owner'
end
puts "Created Superadmin: #{superadmin.full_name}"

# B. Managers (Will be used to create most events)
managers = NUM_MANAGERS.times.map do |i|
  User.find_or_create_by!(email: "manager_#{i+1}@example.com") do |u|
    u.password = '12345678'
    u.role = :manager
    u.full_name = Faker::Name.name + " (Manager #{i+1})"
  end
end
puts "Created #{managers.count} Managers."

# C. Team Members (Staff who are not Admins)
team_members = NUM_TEAM_MEMBERS.times.map do |i|
  User.find_or_create_by!(email: "staff_#{i+1}@example.com") do |u|
    u.password = '12345678'
    u.role = :member
    u.full_name = Faker::Name.name + " (Staff #{i+1})"
  end
end
puts "Created #{team_members.count} Team Members."

# D. Unauthorized Member (For testing 403 Forbidden)
unauthorized_member = User.find_or_create_by!(email: 'unauthorized@example.com') do |u|
  u.password = '12345678'
  u.role = :member
  u.full_name = 'Unauthorized Member'
end

# E. Participant (For ticket ownership)
participant_user = User.find_or_create_by!(email: 'participant@example.com') do |u|
  u.password = '12345678'
  u.role = :member
  u.full_name = 'Sarah Ticket Holder'
end
puts "Created participant user: #{participant_user.full_name}"

# Combined users for easy random assignment
all_event_staff = managers + team_members


# --- 2. EVENT GENERATION (Loop) ---
puts "\n--- 2. Generating #{NUM_EVENTS} Events ---"

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
  )

  EventLocation.create!(
    event: event,
    name: Faker::Address.full_address, # Use 'name' for the location string
    scan_limit: 100 
  )
  
  # Assign a random manager as the EventAdmin
  admin_user = managers.sample
  EventAdmin.create!(event: event, user: admin_user)

  # Assign a random team member as staff for ~50% of the events
  if i.odd?
    EventTeamMember.create!(event: event, user: team_members.sample)
  end

  puts "  -> Event #{i+1}: #{event.title} (Admin: #{admin_user.full_name})"
  event
end

# --- 3. TICKET TYPE & TICKET GENERATION (Loop) ---
puts "\n--- 3. Generating Ticket Types and Tickets (Total: ~#{NUM_EVENTS * TICKETS_PER_EVENT} Tickets) ---"

all_events.each_with_index do |event, i|
  # Skip generating tickets for the first 3 events to simulate events without tickets
  next if i < 3 

  # Create a couple of ticket types per event
  tt_ga = event.ticket_types.find_or_create_by!(name: 'General Admission') do |tt|
    tt.price = Faker::Commerce.price(range: 50.0..100.0)
  end
  tt_vip = event.ticket_types.find_or_create_by!(name: 'VIP Pass') do |tt|
    tt.price = Faker::Commerce.price(range: 200.0..500.0)
  end
  
  ticket_types = [tt_ga, tt_vip]
  
  # Generate tickets with varied statuses
  TICKETS_PER_EVENT.times do |j|
    
    # Cycle through statuses: purchased, scanned, refunded, canceled
    status = Ticket.statuses.keys[j % Ticket.statuses.keys.count] 
    
    # Get the user who is an admin or team member for the event to simulate a scanner
    scanner = event.admins.sample || event.team_members.sample
    
    ticket_attributes = {
      event: event,
      ticket_type: ticket_types.sample,
      user: participant_user, # Assign to our participant user
      attendee_name: Faker::Name.name,
      attendee_email: Faker::Internet.email,
      status: status,
      checked_in: status == 'scanned',
      scanned_by: status == 'scanned' ? scanner : nil,
      check_in_at: status == 'scanned' ? Time.current - rand(1..10).hours : nil
    }

    # Use Ticket.create! to ensure all models and validations are run
    Ticket.create!(ticket_attributes)
  end
end

puts "\n-------------------- Seeding Complete --------------------"
puts "Summary:"
puts "  Total Users: #{User.count}"
puts "  Total Events: #{Event.count}"
puts "  Total Tickets: #{Ticket.count}"
puts "\nLogin Credentials:"
puts "  Superadmin (Org Owner): superadmin@example.com / 12345678"
puts "  Manager (Alice Organizer): manager_1@example.com / 12345678"
puts "  Team Member (Staff 1): staff_1@example.com / 12345678"
puts "  Participant: participant@example.com / 12345678"