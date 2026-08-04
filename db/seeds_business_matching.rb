# frozen_string_literal: true

# To run this script: bundle exec rails runner db/seeds_business_matching.rb

puts "--- START SEEDING 1-HOST-1-SESSION BUSINESS MATCHING DATA (200 PARTICIPANTS) ---"

# 1. Create a Realistic Event
event = Event.find_or_initialize_by(slug: "global-tech-matchmaking-expo-2026")
event.assign_attributes(
  title: "Global Tech Matchmaking Expo 2026",
  start_date: 2.days.from_now.beginning_of_day,
  end_date: 4.days.from_now.end_of_day,
  use_business_matching: true,
  description: "The premier matchmaking event connecting global tech innovators, startup founders, and leading venture capitalists.",
  venue_name: "Kuala Lumpur Convention Centre",
  venue_address: "Jalan Pinang, Kuala Lumpur, 50088 Kuala Lumpur, Wilayah Persekutuan Kuala Lumpur"
)
event.save!
puts "Created Event: #{event.title} (ID: #{event.id})"

# Define Tag pools for realistic profiling
tech_offerings = ["Fintech Core", "Cybersecurity SaaS", "Generative AI API", "AI Diagnostics", "IoT Fleet Tech", "No-Code Builder"]
capital_offerings = ["Pre-Seed Fund", "Seed Venture Capital", "Series A Equity"]
talent_offerings = ["Senior Ruby Developer", "React Frontend Engineer", "AI Researcher", "Product Manager"]

tech_interests = ["Enterprise Partners", "B2B Sales Leads", "API Integrators"]
capital_interests = ["AI Startups", "Fintech Disruptors", "Seed Teams"]
talent_interests = ["Full-time Position", "Remote Contracts", "Co-Founder Match"]

# Seed the event's admin-curated tag list so these tags are actually
# manageable (edit/delete) from the admin Business Matching UI, and so
# hosts/attendees below are only assigned tags that exist in this list.
event.update!(
  business_matching_offering_tags: (tech_offerings + capital_offerings + talent_offerings).uniq,
  business_matching_interest_tags: (tech_interests + capital_interests + talent_interests).uniq
)

# Clear existing data for a clean seed run
BusinessMatchingBooking.joins(:business_matching_session).where(business_matching_sessions: { event_id: event.id }).destroy_all
BusinessMatchingAvailability.joins(:business_matching_session).where(business_matching_sessions: { event_id: event.id }).destroy_all
BusinessHostAssignment.where(event_id: event.id).destroy_all
BusinessMatchingSession.where(event_id: event.id).destroy_all
BusinessMatchingParticipant.where(event_id: event.id).destroy_all

first_names = %w[James John Robert Michael William David Richard Joseph Thomas Charles Mary Patricia Jennifer Elizabeth Linda Barbara Susan Jessica]
last_names = %w[Smith Johnson Williams Brown Jones Garcia Miller Davis Rodriguez Martinez Lee Perez Thompson White Harris Sanchez Clark]
companies = ["NexaTech", "Vanguard Labs", "BioSphere AI", "Quantum Corp", "FinTech Hub", "Novus Capital", "Helios Energy", "Synergy Health"]

# 2. Generate 100 Exhibitor Users & create a unique Session for each (1 Host = 1 Session)
puts "Generating 100 Exhibitors & 100 Sessions..."
exhibitors = []
100.times do |i|
  first_name = first_names.sample
  last_name = last_names.sample
  full_name = "#{first_name} #{last_name}"
  email = "exhibitor.#{first_name.downcase}.#{last_name.downcase}.#{i}@techmatch2026.com"
  company = companies.sample
  booth = "Booth B#{i + 1}"
  
  user = User.find_or_initialize_by(email: email)
  user.assign_attributes(
    full_name: full_name,
    password: "12345678", # Default password
    role: :exhibitor,
    status: :active,
    jti: SecureRandom.uuid
  )
  user.save!

  # Create a dedicated session for this specific host
  session = BusinessMatchingSession.create!(
    event: event,
    title: "#{company} Matchmaking",
    slot_duration: 30,
    location: "#{booth} (Hall 3)",
    admin_email: email,
    admin_wa_number: "+6012#{rand(10000000..99999999)}",
    start_time: "09:00",
    end_time: "17:00",
    is_active: true
  )

  # Assign this user as the host for this session
  BusinessHostAssignment.create!(
    user: user,
    event: event,
    business_matching_event_id: session.id.to_s
  )

  # Initialize default availability days for this host in their session
  start_date = event.start_date.to_date
  end_date = event.end_date.to_date
  (start_date..end_date).each do |day|
    BusinessMatchingAvailability.create!(
      business_matching_session: session,
      host_user_id: user.id,
      day: day,
      start_time: "09:00",
      end_time: "17:00"
    )
  end

  # Setup participant profile
  is_investor = rand < 0.2
  offerings = is_investor ? capital_offerings.sample(2) : tech_offerings.sample(2)
  interests = is_investor ? capital_interests.sample(2) : tech_interests.sample(2)

  p = BusinessMatchingParticipant.find_or_initialize_by(
    event: event,
    registerable: user
  )
  p.update!(
    profile_data: {
      company_name: company,
      offering_tags: offerings,
      interest_tags: interests
    }
  )

  exhibitors << { user: user, session: session, participant: p }
end

# 3. Generate 100 Visitors (Attendees)
puts "Generating 100 Visitors..."
visitors = []
100.times do |i|
  first_name = first_names.sample
  last_name = last_names.sample
  full_name = "#{first_name} #{last_name}"
  email = "visitor.#{first_name.downcase}.#{last_name.downcase}.#{i}@visitor2026.com"
  phone = "+601#{rand(10000000..99999999)}"

  visitor = Visitor.find_or_initialize_by(event: event, email: email)
  visitor.assign_attributes(
    full_name: full_name,
    phone: phone,
    rsvp_status: :attending
  )
  visitor.save!

  p = BusinessMatchingParticipant.find_or_initialize_by(
    event: event,
    registerable: visitor
  )
  p.update!(
    profile_data: {
      company_name: "#{companies.sample} Partner",
      offering_tags: tech_offerings.sample(2),
      interest_tags: tech_interests.sample(2)
    }
  )
  visitors << p
end

puts "Successfully created 200 Matchmaking Participants with 100 unique host sessions."

# 4. Generate 150 Auto-Approved Bookings
puts "Scheduling 150 bookings (Auto-Approved)..."
dates = [event.start_date.to_date, event.start_date.to_date + 1.day]
times = [
  "09:00 AM", "09:30 AM", "10:00 AM", "10:30 AM", "11:00 AM", "11:30 AM",
  "01:30 PM", "02:00 PM", "02:30 PM", "03:00 PM", "03:30 PM", "04:00 PM",
  "04:30 PM"
]

booking_count = 0
attempts = 0
busy_slots = {}

while booking_count < 150 && attempts < 3000
  attempts += 1

  # Select a random host session & a random visitor
  host_data = exhibitors.sample
  visitor_p = visitors.sample

  date = dates.sample
  time = times.sample

  host_key = "#{host_data[:user].id}_#{date}_#{time}"
  visitor_key = "#{visitor_p.id}_#{date}_#{time}"

  next if busy_slots[host_key] || busy_slots[visitor_key]

  # All bookings created as Approved (Auto-Approved)
  booking = BusinessMatchingBooking.new(
    business_matching_session: host_data[:session],
    requester_participant: visitor_p,
    receiver_participant: host_data[:participant],
    host_user: host_data[:user],
    name: visitor_p.registerable.full_name,
    email: visitor_p.registerable.email,
    phone: visitor_p.registerable.phone || "+6012000000",
    booking_date: date,
    booking_time: time,
    duration: 30,
    status: "Approved", # Auto-Approved
    payment_status: "Pending"
  )

  if booking.save
    booking_count += 1
    busy_slots[host_key] = true
    busy_slots[visitor_key] = true
  end
end

puts "Successfully scheduled #{booking_count} auto-approved bookings across 100 distinct host sessions."
puts "--- SEEDING COMPLETED SUCCESSFULLY ---"
