# frozen_string_literal: true

# Realistic feedback forms on dev events, for manual testing of the builder,
# preview and attendee flow. Idempotent: events that already have a form are
# skipped, so it never overwrites real work.
#
#   bin/rails runner db/seeds_feedback_demo.rb
abort 'Development only' unless Rails.env.development?

BASE_URL = ENV.fetch('PANEL_URL', 'http://localhost:3001')
RATING5 = %w[Poor Fair Good Very\ good Excellent].freeze

# Small builder so each form below reads like the form an organizer would build.
class DemoForm
  attr_reader :questions

  def initialize
    @questions = []
  end

  def ask(text, type, page: 1, required: true, options: nil, hint: nil, placeholder: nil, rules: [])
    @questions << { question_text: text, question_type: type, page_number: page, required:,
                    options:, hint_text: hint, placeholder:, routing_rules: rules,
                    position: @questions.length }
  end

  def rating(text, page: 1, required: true, hint: nil, labels: nil)
    ask(text, :rating, page:, required:, hint:, options: labels)
  end

  def text(text, page: 1, required: false, hint: nil, placeholder: nil)
    ask(text, :text, page:, required:, hint:, placeholder:)
  end

  def choice(text, options, page: 1, required: true, hint: nil, rules: [])
    ask(text, :single_choice, page:, required:, options:, hint:, rules:)
  end

  def multi(text, options, page: 1, required: true, hint: nil)
    ask(text, :multi_choice, page:, required:, options:, hint:)
  end

  def yes_no(text, page: 1, required: true, hint: nil)
    ask(text, :yes_no, page:, required:, hint:)
  end
end

def jump(answer, page) = { 'answer' => answer, 'action' => 'jump_to_page', 'target_page' => page }
def submit_rule(answer) = { 'answer' => answer, 'action' => 'submit', 'target_page' => nil }

FORMS = []

def form(event_id, label, title:, description:, mode:, pages: [], thank_you: nil, active: true, &block)
  builder = DemoForm.new
  block.call(builder)
  FORMS << { event_id:, label:, title:, description:, mode:, pages:, thank_you:, active:, questions: builder.questions }
end

# 1. Simple, single page, no conditions.
form(6, 'Simple / single page', title: 'Startup Expo 2026 feedback', mode: :continuous,
     description: 'Two minutes, five questions. Tell us how the day went.',
     thank_you: ['Thanks for being part of Startup Expo!', 'Your feedback shapes next year’s lineup.']) do |f|
  f.rating 'How would you rate Startup Expo 2026 overall?', labels: RATING5
  f.yes_no 'Would you attend again next year?'
  f.multi 'Which parts did you enjoy most?', ['Keynotes', 'Pitch competition', 'Startup booths', 'Networking mixer', 'Workshops'], required: false
  f.text 'Anything we should improve?', placeholder: 'Tell us what would have made your day better'
end

# 2. Multi page, no conditions.
form(4, 'Multi page / no conditions', title: 'Conference experience survey', mode: :pages,
     description: 'Three short pages: overall, sessions, and venue.',
     pages: [{ 'page_number' => 1, 'title' => 'Overall' }, { 'page_number' => 2, 'title' => 'Sessions & speakers' },
             { 'page_number' => 3, 'title' => 'Venue & logistics' }]) do |f|
  f.rating 'Overall, how satisfied were you with the conference?', labels: RATING5
  f.choice 'How did you hear about us?', ['Social media', 'Email', 'Friend or colleague', 'Search', 'Other'], required: false
  f.rating 'How would you rate the quality of the speakers?', page: 2
  f.multi 'Which sessions did you attend?', ['Opening keynote', 'Product roadmap panel', 'Hands-on lab', 'Closing fireside chat'], page: 2, required: false
  f.text 'Which session was most valuable, and why?', page: 2, placeholder: 'Optional'
  f.rating 'How would you rate the venue?', page: 3
  f.choice 'How was check-in?', ['Very smooth', 'Some waiting', 'Long queue'], page: 3
  f.text 'Any logistics issues we should know about?', page: 3
end

# 3. Multi page, skip ahead: "No" jumps past the workshop page.
form(5, 'Multi page / conditional skip', title: 'Workshop & event feedback', mode: :pages,
     description: 'If you skipped the workshops, we will jump you straight to the overall questions.',
     pages: [{ 'page_number' => 1, 'title' => 'Workshops' }, { 'page_number' => 2, 'title' => 'Workshop details' },
             { 'page_number' => 3, 'title' => 'Overall' }]) do |f|
  f.choice 'Did you attend the hands-on workshops?', %w[Yes No], rules: [jump('No', 3)]
  f.rating 'How useful were the workshops?', page: 2
  f.text 'What would you change about the workshops?', page: 2, required: true
  f.rating 'How would you rate the event overall?', page: 3, labels: RATING5
  f.text 'Any final comments?', page: 3
end

# 4. Multi page, two tracks that rejoin.
form(7, 'Multi page / two tracks rejoin', title: 'Track feedback', mode: :pages,
     description: 'Your next page depends on the track you followed.',
     pages: [{ 'page_number' => 1, 'title' => 'Your track' }, { 'page_number' => 2, 'title' => 'Business track' },
             { 'page_number' => 3, 'title' => 'Technical track' }, { 'page_number' => 4, 'title' => 'Exhibition & overall' }]) do |f|
  f.choice 'Which track did you mostly follow?', ['Business track', 'Technical track', 'I only visited the exhibition'],
           rules: [jump('Business track', 2), jump('Technical track', 3), jump('I only visited the exhibition', 4)]
  f.rating 'How relevant was the business content to your work?', page: 2
  f.text 'Which business session should we repeat?', page: 2
  f.rating 'How would you rate the technical sessions?', page: 3
  f.choice 'Was the technical depth right for you?', ['Too basic', 'Just right', 'Too advanced'], page: 3
  f.rating 'How would you rate the exhibition floor?', page: 4
  f.rating 'How would you rate the event overall?', page: 4, labels: RATING5
  f.text 'Anything else?', page: 4
end

# 5. Single page, conditional sections (the "How was the food?" case).
form(8, 'Single page / conditional sections', title: 'Event & catering feedback', mode: :continuous,
     description: 'Answer the food question and the matching section appears.',
     pages: [{ 'page_number' => 1, 'title' => 'The basics' }, { 'page_number' => 2, 'title' => 'What you loved' },
             { 'page_number' => 3, 'title' => 'What went wrong' }, { 'page_number' => 4, 'title' => 'Final thoughts' }]) do |f|
  f.rating 'How would you rate the event overall?', labels: RATING5
  f.choice 'How was the food?', ['Delicious, would recommend', 'Could be better'],
           rules: [jump('Delicious, would recommend', 2), jump('Could be better', 3)]
  f.multi 'What did you love?', %w[Variety Freshness Portions Dietary\ options], page: 2
  f.text 'Any dish you would like to see again?', page: 2
  f.multi 'What went wrong?', ['Long queue', 'Food was cold', 'Limited choices', 'Dietary needs not met'], page: 3
  f.text 'How could we fix it?', page: 3, required: true, placeholder: 'Be as specific as you like'
  f.text 'Any final thoughts?', page: 4
end

# 6. Kitchen sink: every question type, hints, placeholders, optional questions.
form(9, 'Multi page / every question type', title: 'Full attendee survey', mode: :pages,
     description: 'A long form using every question type, hint and option.',
     pages: [{ 'page_number' => 1, 'title' => 'About you' }, { 'page_number' => 2, 'title' => 'The event' },
             { 'page_number' => 3, 'title' => 'Looking ahead' }],
     thank_you: ['All done, thank you!', 'We read every response.']) do |f|
  f.choice 'What best describes you?', %w[Founder Investor Engineer Student Other], hint: 'Pick the closest match.'
  f.yes_no 'Is this your first time at the event?', required: false
  f.rating 'How easy was it to find your way around?', page: 2, hint: '1 is very confusing, 5 is very easy.'
  f.rating 'How was the Wi-Fi?', page: 2, required: false, labels: ['Unusable', 'Slow', 'OK', 'Fast', 'Flawless']
  f.multi 'Which amenities did you use?', ['Coffee bar', 'Charging station', 'Quiet room', 'Coat check'], page: 2, required: false
  f.text 'Tell us about the highlight of your day.', page: 2, placeholder: 'A session, a person, a moment…'
  f.yes_no 'Would you recommend this event to a colleague?', page: 3
  f.text 'What should we add next year?', page: 3, hint: 'Speakers, topics, formats, anything.'
end

# 7. Closed form: the attendee sees the closing message.
form(10, 'Closed form', title: 'Post-event survey (closed)', mode: :continuous, active: false,
     description: 'This survey is no longer taking responses.') do |f|
  f.rating 'How would you rate the event?'
  f.text 'Comments?'
end

# 8. Form that already has responses (tests live-edit locks and analytics).
form(11, 'Has responses (live-edit locks)', title: 'Quick pulse survey', mode: :pages,
     description: 'Already answered by three attendees; try editing it.') do |f|
  f.choice 'Which day did you enjoy most?', ['Day 1', 'Day 2', 'Day 3'], rules: []
  f.rating 'How would you rate the event overall?', labels: RATING5
  f.text 'What is one thing we should keep?'
end

# 9. Early submit rule: "No" ends the survey.
form(12, 'Multi page / early submit rule', title: 'Attendance & feedback', mode: :pages,
     description: 'People who did not attend finish after the first question.',
     pages: [{ 'page_number' => 1, 'title' => 'Attendance' }, { 'page_number' => 2, 'title' => 'Your experience' }]) do |f|
  f.choice 'Did you attend the event in person?', ['Yes', 'No', 'I watched online'], rules: [submit_rule('No')]
  f.rating 'How would you rate your experience?', page: 2
  f.text 'What was the highlight?', page: 2
end

REPORT = []

FORMS.each do |spec|
  event = Event.find_by(id: spec[:event_id])
  next puts("skip event #{spec[:event_id]}: not found") unless event
  next puts("skip event #{event.id}: already has a feedback form") if event.feedback_form

  event.update_columns(use_feedback: true)
  form = FeedbackForm.create!(
    event:, title: spec[:title], description: spec[:description], display_mode: spec[:mode],
    is_active: spec[:active], pages_metadata: spec[:pages],
    thank_you_title: spec[:thank_you]&.first, thank_you_message: spec[:thank_you]&.last
  )
  spec[:questions].each { |attrs| form.feedback_questions.create!(attrs) }

  if spec[:event_id] == 11
    q = form.feedback_questions.order(:position).to_a
    event.tickets.where(status: %w[scanned purchased]).limit(3).each_with_index do |ticket, i|
      response = form.feedback_responses.create!(ticket:, submitted_at: (i + 1).hours.ago)
      response.feedback_answers.create!(feedback_question: q[0], answer_text: ['Day 1', 'Day 2', 'Day 2'][i])
      response.feedback_answers.create!(feedback_question: q[1], answer_text: %w[5 4 3][i])
      response.feedback_answers.create!(feedback_question: q[2], answer_text: ['The keynote', 'The workshops', 'Coffee!'][i])
    end
  end

  attendees = event.tickets.where(status: %w[scanned purchased])
                   .where.not(id: form.feedback_responses.select(:ticket_id)).limit(2)
  REPORT << [event, spec, form, attendees]
end

REPORT.each do |event, spec, form, attendees|
  puts "\n#{spec[:label]}  (event #{event.id}, #{spec[:mode]}, #{form.feedback_questions.count} questions#{spec[:active] ? '' : ', CLOSED'})"
  puts "  builder:  #{BASE_URL}/event/#{event.id}/feedback/form-builder"
  puts "  preview:  #{BASE_URL}/events/#{event.slug}/feedback"
  attendees.each { |t| puts "  attendee: #{BASE_URL}/events/#{event.slug}/feedback?ticket=#{t.public_id}  (#{t.attendee_name})" }
end
