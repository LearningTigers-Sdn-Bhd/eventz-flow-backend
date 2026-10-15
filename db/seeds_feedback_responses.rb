# frozen_string_literal: true

# Realistic attendees and feedback responses for the demo forms created by
# db/seeds_feedback_demo.rb, so the responses page, exports and AI summary have
# something meaningful to show.
#
#   bin/rails runner db/seeds_feedback_responses.rb
#   FORCE=1 bin/rails runner db/seeds_feedback_responses.rb   # top up forms that already have responses
#   EVENT_IDS=9 ATTENDEES=4000 RATE=0.75 FORCE=1 bin/rails runner db/seeds_feedback_responses.rb   # scale test (~3,000 responses)
#
# Safe to re-run: attendees are tagged by email domain, tickets that already
# responded are skipped, and only events with ticket types and a form are used.
abort 'Development only' unless Rails.env.development?

# Creating a ticket sends a confirmation email (and, in dev, pops a letter_opener
# browser tab). Silence all mail and background jobs while seeding.
ActionMailer::Base.perform_deliveries = false
ActiveJob::Base.queue_adapter = :test

DEMO_DOMAIN = 'feedback-demo.test'
TARGET_EVENT_IDS = (ENV['EVENT_IDS'] || '4,5,6,7,8,9,10,11,12').split(',').map(&:to_i)

FIRST_NAMES = %w[
  Aisyah Daniel Mei\ Ling Arjun Sofia Hafiz Priya Jason Nurul Marcus Siti Kevin Wei\ Jie Amira Raj Chloe Farid
  Grace Ethan Liyana Ben Sharifah Darren Nadia Jun\ Hao Isabelle Kumar Aaron Farah Lucas Yu\ Xuan Zul Hannah
  Vincent Dayang Samuel Jia\ Hui Irfan Emily Tariq Bryan Sarah Amar Li\ Na Joshua Zara Ryan Natasha Hakim Olivia
].freeze
LAST_NAMES = %w[
  Tan Lim Abdullah Wong Kumar Lee Ismail Chong Rahman Nair Yap Hassan Ong Singh Chin Yusof Goh Mohamed Lau Pillai
  Teo Ahmad Ho Krishnan Low Said Chan Raj Koh Jaafar Liew Sim Mustafa Ng Anand Wee Osman Foo Ramli Gan
].freeze

# Mood drives how an attendee answers every question, so a response reads consistently.
MOODS = { delighted: 0.34, happy: 0.30, neutral: 0.16, unhappy: 0.14, angry: 0.06 }.freeze
RATING_CHOICES = {
  delighted: [[5, 85], [4, 15]], happy: [[4, 70], [5, 20], [3, 10]], neutral: [[3, 70], [4, 15], [2, 15]],
  unhappy: [[2, 60], [1, 20], [3, 20]], angry: [[1, 75], [2, 25]]
}.freeze

COMMENTS = {
  positive: [
    'Loved the atmosphere, everything ran on time.', 'The speakers were genuinely inspiring.',
    'Great networking opportunities, met two future partners.', 'Well organised from check-in to closing.',
    'The venue was comfortable and easy to find.', 'Staff were friendly and always ready to help.',
    'Best event I have attended this year.', 'Fantastic lineup, would come again in a heartbeat.',
    'Loved the variety of sessions, something for everyone.', 'Super smooth registration, no queue at all.',
    'The hands-on workshop was the highlight of my day.', 'Really well curated exhibitors, learned a lot.'
  ],
  neutral: [
    'Decent event overall, a few things could be smoother.', 'Good content but the schedule felt a bit packed.',
    'Enjoyed the talks, although some ran over time.', 'Nice venue, a little noisy near the exhibition hall.',
    'Average experience, nothing really stood out.', 'Some sessions were great, others less relevant for me.'
  ],
  negative: [
    'The queue at registration took almost 40 minutes.', 'Wi-Fi kept dropping during the demos.',
    'Food ran out before I could get any.', 'Too crowded in the main hall, hard to move around.',
    'Signage was confusing, I got lost twice.', 'Sessions started late and overran the schedule.',
    'Parking was a nightmare and there was no guidance.', 'The room was freezing and the sound kept cutting out.',
    'Would have liked clearer communication before the event.', 'The last session felt rushed and poorly prepared.'
  ]
}.freeze

TOPIC_COMMENTS = {
  /food|catering|lunch|dish/ => {
    positive: ['The food was delicious and plentiful.', 'Loved the local dishes, great variety.', 'Lunch was excellent, dietary options were clear.'],
    negative: ['Food was cold by the time I got to it.', 'Very limited vegetarian choices.', 'Long queue for lunch, missed part of the afternoon session.']
  },
  /wi-?fi|internet/ => {
    positive: ['Wi-Fi was fast even in the main hall.'],
    negative: ['Wi-Fi was unusable during the keynote.', 'Connection dropped every few minutes.']
  },
  /improve|change|fix|add|next year/ => {
    positive: ['More hands-on sessions please!', 'Add a dedicated networking hour.', 'Keep the same format next year, it worked.'],
    negative: ['Better crowd control and more seating.', 'Please stagger the start times to avoid queues.', 'More microphones for audience Q&A.']
  },
  /highlight|valuable|loved|enjoy/ => {
    positive: ['The closing fireside chat was brilliant.', 'The product demos, hands down.', 'Meeting the founders in person.'],
    negative: ['Honestly the coffee breaks, sorry.']
  },
  /venue|logistic|check-?in/ => {
    positive: ['Venue was spacious and well signposted.', 'Check-in took under a minute.'],
    negative: ['Not enough toilets near the main hall.', 'Check-in desks were understaffed.']
  }
}.freeze

# Awkward but realistic text that exports and the UI must survive.
EDGE_COMMENTS = [
  '=SUM(1+1) was what I paid for the ticket, honestly worth it',
  '+60 12-345 6789 call me about sponsorship',
  "Great event!\nThe second day was even better.",
  'Said "wow" twice, and, yes, I meant it; 10/10',
  '他のイベントよりもずっと良かったです 😊',
  '@organizer please share the slides'
].freeze

def weighted(pairs, rng)
  total = pairs.sum { |_, w| w }
  roll = rng.rand * total
  pairs.each { |value, w| return value if (roll -= w) <= 0 }
  pairs.last.first
end

def pick_mood(rng, vip:)
  weights = MOODS.to_a
  weights = weights.map { |m, w| [m, m == :delighted && vip ? w * 1.3 : w] } if vip
  weighted(weights, rng)
end

def comment_for(question, mood, rng)
  tone = { delighted: :positive, happy: :positive, neutral: :neutral, unhappy: :negative, angry: :negative }[mood]
  text = question.question_text.downcase
  topic = TOPIC_COMMENTS.find { |pattern, _| text.match?(pattern) }&.last
  pool = topic && topic[tone == :neutral ? :positive : tone] if topic
  pool = COMMENTS[tone] if pool.nil? || pool.empty? || rng.rand < 0.35
  pool.sample(random: rng)
end

def choice_for(question, mood, rng)
  options = Array(question.options)
  return options.sample(random: rng) if options.length < 2 || rng.rand < 0.4

  bias = { delighted: 0.0, happy: 0.25, neutral: 0.5, unhappy: 0.75, angry: 1.0 }[mood]
  index = ((bias + (rng.rand - 0.5) * 0.5).clamp(0.0, 1.0) * (options.length - 1)).round
  options[index]
end

def answer_for(question, mood, rng)
  case question.question_type
  when 'rating' then weighted(RATING_CHOICES.fetch(mood), rng).to_s
  when 'yes_no' then rng.rand < { delighted: 0.95, happy: 0.85, neutral: 0.55, unhappy: 0.25, angry: 0.1 }[mood] ? 'yes' : 'no'
  when 'single_choice' then choice_for(question, mood, rng)
  when 'multi_choice' then Array(question.options).sample(rng.rand(1..[3, question.options.length].min), random: rng).to_json
  when 'text' then comment_for(question, mood, rng)
  end
end

# Walk the form the way an attendee would, so skipped branches stay empty.
def build_answers(form, questions, mood, rng)
  routing = FeedbackRouting.new(questions, continuous: form.continuous?)
  answers = {}
  attempted = []
  50.times do
    question = routing.reachable_questions(answers).find { |q| !attempted.include?(q.id) }
    break unless question

    attempted << question.id
    skip_chance = question.required? ? 0 : (question.text? ? 0.45 : 0.25)
    next if rng.rand < skip_chance

    answers[question.id] = answer_for(question, mood, rng)
  end
  answers
end

def ensure_attendees(event, target, rng)
  existing = event.tickets.where('attendee_email LIKE ?', "%@#{DEMO_DOMAIN}").count
  types = event.ticket_types.order(:id).to_a
  (target - existing).times do |i|
    first = FIRST_NAMES.sample(random: rng)
    last = LAST_NAMES.sample(random: rng)
    type = rng.rand < 0.22 ? types.last : types.first
    Ticket.create!(
      event:, ticket_type: type, attendee_name: "#{first} #{last}", status: :purchased, payment_status: :paid,
      attendee_email: "#{first}.#{last}.#{event.id}.#{existing + i}@#{DEMO_DOMAIN}".downcase.delete(' '),
      checked_in: true, check_in_at: event.start_date + rng.rand(1..6).hours
    )
  end
end

summary = []

TARGET_EVENT_IDS.each do |event_id|
  event = Event.find_by(id: event_id)
  form = event&.feedback_form
  next puts("skip event #{event_id}: no event or form") unless form
  next puts("skip event #{event_id}: no ticket types") if event.ticket_types.empty?
  if form.feedback_responses.count >= 10 && !ENV['FORCE']
    next puts("skip event #{event_id}: already has #{form.feedback_responses.count} responses (FORCE=1 to top up)")
  end

  rng = Random.new(2026_09_30 + event_id)
  target_attendees = (ENV['ATTENDEES'] || (70 + (event_id * 7 % 50))).to_i # default 70–119 per event
  response_rate = (ENV['RATE'] || (0.42 + (event_id * 13 % 30) / 100.0)).to_f # default 42–71%

  ensure_attendees(event, target_attendees, rng)
  event.create_event_email_setting!(thank_you_include_feedback: true) unless event.event_email_setting
  event.event_email_setting.update!(thank_you_include_feedback: true)

  questions = form.feedback_questions.to_a
  responded_ids = form.feedback_responses.where.not(ticket_id: nil).pluck(:ticket_id)
  tickets = event.tickets.where(checked_in: true).where.not(id: responded_ids)
                 .where('attendee_email LIKE ?', "%@#{DEMO_DOMAIN}").to_a.shuffle(random: rng)
  responders = tickets.first((tickets.length * response_rate).round)
  edge = EDGE_COMMENTS.dup
  text_question = questions.find(&:text?)

  # Build everything in memory, then insert in batches (thousands of rows stay fast).
  pending = []
  responders.each do |ticket|
    mood = pick_mood(rng, vip: ticket.ticket_type_id == event.ticket_types.order(:id).last.id)
    answers = build_answers(form, questions, mood, rng)
    next if answers.empty?

    if text_question && answers.key?(text_question.id) && (special = edge.shift)
      answers[text_question.id] = special
    end

    # Most replies arrive in the first two days after the event, then trickle in.
    hours = (-Math.log(1 - rng.rand) * 40).clamp(1, 14 * 24)
    pending << { ticket_id: ticket.id, submitted_at: [event.end_date + hours.hours, Time.current].min, answers: }
  end

  pending.each_slice(500) do |slice|
    ids = FeedbackResponse.insert_all(
      slice.map { |r| { feedback_form_id: form.id, ticket_id: r[:ticket_id], submitted_at: r[:submitted_at] } },
      returning: %w[id]
    ).rows.flatten
    abort 'response insert skipped rows' unless ids.length == slice.length

    FeedbackAnswer.insert_all(slice.each_with_index.flat_map do |r, i|
      r[:answers].map { |question_id, text| { feedback_response_id: ids[i], feedback_question_id: question_id, answer_text: text } }
    end)
  end
  created = pending.length

  summary << [event, form, created, event.tickets.where(checked_in: true).count]
end

puts
summary.each do |event, form, created, checked_in|
  total = form.feedback_responses.count
  puts format('event %-3d %-36s +%-3d responses (total %d of %d checked-in, %.0f%%)',
              event.id, form.title.truncate(36), created, total, checked_in, total * 100.0 / checked_in)
end
