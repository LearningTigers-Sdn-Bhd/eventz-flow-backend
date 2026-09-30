require 'rails_helper'

RSpec.describe 'Feedback reports', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:event) do
    record = create(:event, start_date: 5.days.ago, end_date: 2.days.ago)
    create(:event_assignment, role: :event_admin, event: record, user: organizer)
    record
  end
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" } }
  let(:base) { "/v1/events/#{event.id}/feedback_form" }
  let!(:form) { FeedbackForm.create!(event:, title: 'Survey') }
  let!(:rating) do
    form.feedback_questions.create!(question_text: 'Rate', question_type: :rating, position: 0, routing_rules: [])
  end
  let!(:comment) do
    form.feedback_questions.create!(question_text: 'Comments', question_type: :text, required: false, position: 1,
                                    routing_rules: [])
  end
  let(:ga) { event.ticket_types.first || create(:ticket_type, event:) }
  let(:vip) { create(:ticket_type, event:, name: 'VIP') }

  def attendee(name, type: ga, checked_in: true, status: :purchased, email: nil)
    create(:ticket, :paid, event:, ticket_type: type, attendee_name: name, status:,
                           attendee_email: email || "#{name.downcase.tr(' ', '.')}@example.com",
                           checked_in:, check_in_at: (Time.current if checked_in))
  end

  def respond(ticket, score, text = nil, at: Time.current)
    r = form.feedback_responses.create!(ticket:, submitted_at: at)
    r.feedback_answers.create!(feedback_question: rating, answer_text: score.to_s)
    r.feedback_answers.create!(feedback_question: comment, answer_text: text) if text
    r
  end

  def json = JSON.parse(response.body)

  describe 'authorization' do
    it 'rejects a user without access to the event' do
      outsider = create(:user, :member)
      get "#{base}/comments",
          headers: { 'Authorization' => "Bearer #{JwtService.generate_tokens(outsider)[:access_token]}" }
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'summary' do
    let!(:a) { attendee('Ann Lee') }
    let!(:b) { attendee('Bo Chan', type: vip) }
    let!(:c) { attendee('Cy Doe') }
    let!(:not_checked_in) { attendee('Dee Fox', checked_in: false) }
    let!(:cancelled) { attendee('Eve Kim', status: :canceled) }

    before do
      respond(a, 5, 'Great day', at: 2.days.ago)
      respond(b, 2, 'Too crowded', at: 1.day.ago)
      respond(not_checked_in, 4) # responded without being checked in: counts as a response, not towards the rate
    end

    it 'reports response rate against checked-in, valid tickets only' do
      get "#{base}/summary", headers: headers
      rate = json.dig('data', 'response_rate')
      expect(json.dig('data', 'total_responses')).to eq(3)
      expect(rate).to include('eligible' => 3, 'responded' => 2, 'percent' => 66.7)
    end

    it 'has no percent when nobody is eligible' do
      Ticket.update_all(checked_in: false)
      get "#{base}/summary", headers: headers
      expect(json.dig('data', 'response_rate', 'percent')).to be_nil
    end

    it 'adds headline metrics and satisfaction' do
      get "#{base}/summary", headers: headers
      data = json['data']
      expect(data['overall_average']).to eq(3.7)
      expect(data['overall_satisfied_percent']).to eq(66.7)
      q = data['questions'].find { |x| x['id'] == rating.id }
      expect(q).to include('satisfied_count' => 2, 'satisfied_percent' => 66.7, 'seen_count' => 3)
    end

    it 'breaks ratings down by ticket type when several types responded' do
      get "#{base}/summary", headers: headers
      q = json['data']['questions'].find { |x| x['id'] == rating.id }
      expect(q['by_ticket_type'].map { |t| [t['ticket_type_name'], t['average']] }).to include(['VIP', 2.0])
    end

    it 'returns a responses-per-day timeline, oldest day first' do
      # Days with very different counts, so sorting by count instead of date would show.
      3.times { |i| respond(attendee("Busy #{i}"), 4, at: 10.days.ago) }
      respond(attendee('Late Larry'), 4, at: 3.days.ago)

      get "#{base}/summary", headers: headers
      timeline = json.dig('data', 'timeline')
      expect(timeline.sum { |d| d['count'] }).to eq(7)
      expect(timeline.map { |d| d['date'] }).to eq(timeline.map { |d| d['date'] }.sort)
      expect(timeline.first['count']).to eq(3)
    end

    it 'filters by ticket type' do
      get "#{base}/summary", params: { ticket_type_id: vip.id }, headers: headers
      expect(json.dig('data', 'total_responses')).to eq(1)
      expect(json.dig('data', 'response_rate')).to include('eligible' => 1, 'responded' => 1)
    end

    it 'filters by date range (inclusive)' do
      get "#{base}/summary", params: { from: 2.days.ago.to_date.iso8601, to: 2.days.ago.to_date.iso8601 }, headers: headers
      expect(json.dig('data', 'total_responses')).to eq(1)
    end

    it 'rejects a malformed date' do
      get "#{base}/summary", params: { from: 'yesterday-ish' }, headers: headers
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'branch-aware seen_count' do
    let!(:gate) do
      form.feedback_questions.create!(
        question_text: 'Track?', question_type: :single_choice, options: %w[A B], position: 2, page_number: 1,
        routing_rules: [{ 'answer' => 'A', 'action' => 'jump_to_page', 'target_page' => 2 },
                        { 'answer' => 'B', 'action' => 'jump_to_page', 'target_page' => 3 }]
      )
    end
    let!(:track_a) do
      form.feedback_questions.create!(question_text: 'A detail', question_type: :text, position: 3, page_number: 2,
                                      required: false, routing_rules: [])
    end
    let!(:track_b) do
      form.feedback_questions.create!(question_text: 'B detail', question_type: :text, position: 4, page_number: 3,
                                      required: false, routing_rules: [])
    end

    it 'counts only responses that could see each branch' do
      [%w[A x], %w[A y], %w[B z]].each_with_index do |(track, text), i|
        r = form.feedback_responses.create!(ticket: attendee("P#{i}"), submitted_at: Time.current)
        r.feedback_answers.create!(feedback_question: gate, answer_text: track)
        r.feedback_answers.create!(feedback_question: track == 'A' ? track_a : track_b, answer_text: text)
      end

      get "#{base}/summary", headers: headers
      seen = json['data']['questions'].to_h { |q| [q['id'], q['seen_count']] }
      expect(seen).to include(gate.id => 3, track_a.id => 2, track_b.id => 1)
    end
  end

  describe 'comments' do
    let!(:happy) { attendee('Hana Sato') }
    let!(:unhappy) { attendee('Uli Braun', type: vip) }

    before do
      respond(happy, 5, 'Loved the keynote')
      respond(unhappy, 1, 'Queue was far too long')
      # blank comments are ignored
      respond(attendee('Quiet Quinn'), 3, '   ')
    end

    it 'lists comments with attendee and the response score' do
      get "#{base}/comments", headers: headers
      rows = json['data']
      expect(rows.length).to eq(2)
      row = rows.find { |r| r['answer_text'].include?('Queue') }
      expect(row).to include('response_rating' => 1.0, 'question_text' => 'Comments')
      expect(row['attendee']).to include('name' => 'Uli Braun', 'ticket_type_name' => 'VIP')
    end

    it 'searches comment text and attendee name' do
      get "#{base}/comments", params: { q: 'keynote' }, headers: headers
      expect(json['data'].map { |r| r['attendee']['name'] }).to eq(['Hana Sato'])
      get "#{base}/comments", params: { q: 'braun' }, headers: headers
      expect(json['data'].map { |r| r['attendee']['name'] }).to eq(['Uli Braun'])
    end

    it 'finds unhappy attendees with max_rating' do
      get "#{base}/comments", params: { max_rating: 2 }, headers: headers
      expect(json['data'].map { |r| r['attendee']['name'] }).to eq(['Uli Braun'])
    end

    it 'applies the shared ticket type filter' do
      get "#{base}/comments", params: { ticket_type_id: vip.id }, headers: headers
      expect(json['data'].length).to eq(1)
    end

    it 'paginates' do
      get "#{base}/comments", params: { per_page: 1 }, headers: headers
      expect(json['data'].length).to eq(1)
      expect(json['pagination']).to include('total_count' => 2, 'total_pages' => 2)
    end

    it 'returns an empty page when there is no form' do
      form.destroy
      get "#{base}/comments", headers: headers
      expect(json['data']).to eq([])
    end
  end

  describe 'non_responders' do
    let!(:done) { attendee('Done Dana') }
    let!(:waiting) { attendee('Waiting Wes') }

    before do
      respond(done, 4)
      attendee('Not Scanned', checked_in: false)
      attendee('Cancelled Cat', status: :canceled)
    end

    it 'lists checked-in, valid attendees who have not responded' do
      get "#{base}/non_responders", headers: headers
      expect(json['data'].map { |t| t['attendee_name'] }).to eq(['Waiting Wes'])
    end

    it 'searches by name or email' do
      get "#{base}/non_responders", params: { q: 'nobody' }, headers: headers
      expect(json['data']).to eq([])
    end

    it 'handles anonymous responses without hiding everyone (NULL ticket ids)' do
      form.feedback_responses.create!(ticket: nil, submitted_at: Time.current)
      get "#{base}/non_responders", headers: headers
      expect(json['data'].length).to eq(1)
    end
  end

  describe 'remind' do
    let!(:waiting) { attendee('Waiting Wes') }
    let!(:waiting2) { attendee('Waiting Wendy') }

    before do
      event.create_event_email_setting!(thank_you_include_feedback: true)
    end

    it 'queues reminders for the chosen non-responders' do
      expect do
        post "#{base}/remind", params: { ticket_ids: [waiting.public_id] }, headers:, as: :json
      end.to have_enqueued_job(EmailDeliveryJob).once
      expect(response).to have_http_status(:accepted)
      expect(json['data']).to eq('queued' => 1, 'skipped' => 0)
    end

    it 'reminds everyone outstanding with all: true, and skips anyone emailed in the last 24 hours' do
      post "#{base}/remind", params: { ticket_ids: [waiting.public_id] }, headers:, as: :json
      post "#{base}/remind", params: { all: true }, headers:, as: :json
      expect(json['data']).to eq('queued' => 1, 'skipped' => 1)
    end

    it 'never reminds someone who already responded' do
      respond(waiting, 5)
      post "#{base}/remind", params: { ticket_ids: [waiting.public_id] }, headers:, as: :json
      expect(json['data']).to eq('queued' => 0, 'skipped' => 0)
    end

    it 'refuses while the event is still running' do
      event.update!(start_date: 1.day.ago, end_date: 2.days.from_now)
      post "#{base}/remind", params: { all: true }, headers:, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json['message']).to include('not ended')
    end

    it 'refuses when the feedback link is switched off in the thank-you email' do
      event.event_email_setting.update!(thank_you_include_feedback: false)
      post "#{base}/remind", params: { all: true }, headers:, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'export_data' do
    let!(:a) { attendee('Ann Lee') }

    it 'returns form, summary, responses and comments in one payload' do
      multi = form.feedback_questions.create!(question_text: 'Liked', question_type: :multi_choice,
                                              options: %w[Food Talks], required: false, position: 2, routing_rules: [])
      r = respond(a, 5, 'Nice')
      r.feedback_answers.create!(feedback_question: multi, answer_text: '["Food","Talks"]')

      get "#{base}/export_data", headers: headers
      data = json['data']
      expect(data['form']['title']).to eq('Survey')
      expect(data['questions'].map { |q| q['question_text'] }).to eq(%w[Rate Comments Liked])
      expect(data['responses'].length).to eq(1)
      expect(data['responses'][0]['answers'][multi.id.to_s]).to eq(%w[Food Talks])
      expect(data['responses'][0]['ticket']['attendee_email']).to eq('ann.lee@example.com')
      expect(data['comments'].map { |c| c['answer_text'] }).to eq(['Nice'])
      expect(data['summary']['total_responses']).to eq(1)
    end

    it 'respects filters' do
      respond(a, 5)
      get "#{base}/export_data", params: { ticket_type_id: vip.id }, headers: headers
      expect(json['data']['responses']).to eq([])
    end

    it 'refuses exports above the cap with a clear message' do
      stub_const('V1::FeedbackReportsController::EXPORT_LIMIT', 1)
      respond(a, 5)
      respond(attendee('Bea Ray'), 4)
      get "#{base}/export_data", headers: headers
      expect(response).to have_http_status(:unprocessable_content)
      expect(json['message']).to include('Narrow the filters')
    end

    it '404s when there is no form' do
      form.destroy
      get "#{base}/export_data", headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end
end
