require 'swagger_helper'

RSpec.describe 'V1::FeedbackForms', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:regular_user) { create(:user, :member) }
  let(:event) do
    record = create(:event)
    create(:event_assignment, role: :event_admin, event: record, user: organizer)
    record
  end
  let(:organizer_headers) do
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" }
  end
  let(:regular_headers) do
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(regular_user)[:access_token]}" }
  end
  let(:event_id) { event.id }

  path '/v1/events/{event_id}/feedback_form/summary' do
    parameter name: 'event_id', in: :path, type: :integer, description: 'event_id'

    get('summarize feedback responses') do
      tags 'Feedback Forms'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:Authorization) { organizer_headers['Authorization'] }
        let!(:form) { FeedbackForm.create!(event:, title: 'After the event') }

        run_test!
      end

      response(403, 'forbidden') do
        let(:Authorization) { regular_headers['Authorization'] }

        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/feedback_form/responses' do
    parameter name: 'event_id', in: :path, type: :integer, description: 'event_id'
    parameter name: :page, in: :query, type: :integer, required: false
    parameter name: :per_page, in: :query, type: :integer, required: false

    get('list feedback responses') do
      tags 'Feedback Forms'
      produces 'application/json'
      security [bearerAuth: []]

      response(200, 'successful') do
        let(:Authorization) { organizer_headers['Authorization'] }
        let(:page) { 1 }
        let(:per_page) { 25 }
        let!(:form) { FeedbackForm.create!(event:, title: 'After the event') }
        let!(:question) do
          form.feedback_questions.create!(question_text: 'What did you think?', question_type: :text)
        end
        let!(:feedback_response) { form.feedback_responses.create!(submitted_at: Time.current) }
        let!(:answer) do
          feedback_response.feedback_answers.create!(feedback_question: question, answer_text: 'Great event')
        end

        run_test!
      end

      response(403, 'forbidden') do
        let(:Authorization) { regular_headers['Authorization'] }
        let(:page) { 1 }
        let(:per_page) { 25 }

        run_test!
      end
    end
  end

  describe 'POST /v1/events/:event_id/feedback_form' do
    let(:params) do
      {
        feedback_form: {
          title: 'After the event',
          description: 'Tell us what you thought.',
          feedback_questions_attributes: [
            { question_text: 'How was it?', question_type: 'rating', required: true, position: 0 },
            { question_text: 'What should change?', question_type: 'text', position: 1 }
          ]
        }
      }
    end

    it 'creates a form with nested questions' do
      post "/v1/events/#{event.id}/feedback_form", params:, headers: organizer_headers

      expect(response).to have_http_status(:created)
      data = JSON.parse(response.body).fetch('data')
      expect(data['title']).to eq('After the event')
      expect(data['questions'].map { |question| question['question_text'] }).to eq(
        ['How was it?', 'What should change?']
      )
      expect(data['questions'].first['question_type']).to eq('rating')
    end

    it 'rejects a second form for the same event' do
      post "/v1/events/#{event.id}/feedback_form", params:, headers: organizer_headers
      post "/v1/events/#{event.id}/feedback_form", params:, headers: organizer_headers

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'requires event update authorization' do
      post "/v1/events/#{event.id}/feedback_form", params:, headers: regular_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /v1/events/:event_id/feedback_form' do
    it 'returns the event form and ordered questions' do
      form = FeedbackForm.create!(event:, title: 'After the event')
      second = form.feedback_questions.create!(question_text: 'Second', question_type: :text, position: 2)
      first = form.feedback_questions.create!(question_text: 'First', question_type: :rating, position: 1)

      get "/v1/events/#{event.id}/feedback_form", headers: organizer_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig('data', 'questions').map { |question| question['id'] }).to eq(
        [first.id, second.id]
      )
    end
  end

  describe 'GET /v1/events/:event_id/feedback_form/summary' do
    it 'summarizes ratings, choice percentages, multi-choice selections, and latest text answers' do
      form = FeedbackForm.create!(event:, title: 'After the event')
      rating = form.feedback_questions.create!(question_text: 'Rate it', question_type: :rating, position: 0)
      yes_no = form.feedback_questions.create!(question_text: 'Recommend it?', question_type: :yes_no, position: 1)
      single_choice = form.feedback_questions.create!(
        question_text: 'Which session?', question_type: :single_choice, options: %w[Talk Workshop], position: 2
      )
      multi_choice = form.feedback_questions.create!(
        question_text: 'What did you enjoy?', question_type: :multi_choice,
        options: %w[A B C D], position: 3
      )
      text = form.feedback_questions.create!(question_text: 'Anything else?', question_type: :text, position: 4)
      ratings = %w[5 4 3 2 1 5]
      yes_no_answers = %w[yes no yes no yes no]
      single_choice_answers = %w[Talk Workshop Talk Workshop Talk Workshop]
      choices = [%w[A B], %w[A], %w[B C], %w[C], %w[A C], %w[B]]
      submitted_at = 6.times.map { |index| Time.current + index.seconds }

      submitted_at.each_with_index do |time, index|
        feedback_response = form.feedback_responses.create!(submitted_at: time)
        feedback_response.feedback_answers.create!(feedback_question: rating, answer_text: ratings[index])
        feedback_response.feedback_answers.create!(feedback_question: yes_no, answer_text: yes_no_answers[index])
        feedback_response.feedback_answers.create!(
          feedback_question: single_choice, answer_text: single_choice_answers[index]
        )
        feedback_response.feedback_answers.create!(feedback_question: multi_choice, answer_text: choices[index].to_json)
        feedback_response.feedback_answers.create!(feedback_question: text, answer_text: "Comment #{index + 1}")
      end
      blank_response = form.feedback_responses.create!(submitted_at: submitted_at.first - 1.second)
      blank_response.feedback_answers.create!(feedback_question: text, answer_text: '   ')

      get "/v1/events/#{event.id}/feedback_form/summary", headers: organizer_headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body).fetch('data')
      expect(data.fetch('total_responses')).to eq(7)
      expect(Time.zone.parse(data.fetch('last_submitted_at'))).to be_within(0.001).of(submitted_at.last)
      questions = data.fetch('questions').index_by { |question| question.fetch('id') }
      expect(questions.fetch(rating.id)).to include(
        'answered_count' => 6,
        'average' => 3.3,
        'distribution' => { '1' => 1, '2' => 1, '3' => 1, '4' => 1, '5' => 2 }
      )
      expect(questions.fetch(yes_no.id)).to include(
        'answered_count' => 6,
        'options' => [
          { 'label' => 'Yes', 'count' => 3, 'percent' => 50.0 },
          { 'label' => 'No', 'count' => 3, 'percent' => 50.0 }
        ]
      )
      expect(questions.fetch(single_choice.id)).to include(
        'answered_count' => 6,
        'options' => [
          { 'label' => 'Talk', 'count' => 3, 'percent' => 50.0 },
          { 'label' => 'Workshop', 'count' => 3, 'percent' => 50.0 }
        ]
      )
      expect(questions.fetch(multi_choice.id)).to include(
        'answered_count' => 6,
        'options' => [
          { 'label' => 'A', 'count' => 3, 'percent' => 50.0 },
          { 'label' => 'B', 'count' => 3, 'percent' => 50.0 },
          { 'label' => 'C', 'count' => 3, 'percent' => 50.0 },
          { 'label' => 'D', 'count' => 0, 'percent' => 0.0 }
        ]
      )
      expect(questions.fetch(text.id)).to include('answered_count' => 6)
      expect(questions.fetch(text.id).fetch('latest').map { |answer| answer.fetch('answer_text') }).to eq(
        ['Comment 6', 'Comment 5', 'Comment 4', 'Comment 3', 'Comment 2']
      )
    end

    it 'returns no data when the event has no feedback form' do
      get "/v1/events/#{event.id}/feedback_form/summary", headers: organizer_headers

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).not_to have_key('data')
    end

    it 'forbids users without event update permission' do
      get "/v1/events/#{event.id}/feedback_form/summary", headers: regular_headers

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'GET /v1/events/:event_id/feedback_form/responses' do
    it 'paginates newest first and includes ticket details and formatted answers' do
      form = FeedbackForm.create!(event:, title: 'After the event')
      question = form.feedback_questions.create!(
        question_text: 'Which sessions?', question_type: :multi_choice, options: %w[A B]
      )
      ticket = create(:ticket, event:)
      responses = 26.times.map do |index|
        feedback_response = form.feedback_responses.create!(
          submitted_at: Time.current + index.seconds,
          ticket: index == 25 ? ticket : nil
        )
        feedback_response.feedback_answers.create!(
          feedback_question: question, answer_text: '["A","B"]'
        )
        feedback_response
      end

      get "/v1/events/#{event.id}/feedback_form/responses", headers: organizer_headers

      expect(response).to have_http_status(:ok)
      body = JSON.parse(response.body)
      expect(body.fetch('data').length).to eq(25)
      expect(body.dig('pagination', 'per_page')).to eq(25)
      expect(body.fetch('data').first.fetch('id')).to eq(responses.last.id)
      expect(body.fetch('data').first.fetch('ticket')).to include(
        'public_id' => ticket.public_id,
        'attendee_name' => ticket.attendee_name,
        'attendee_email' => ticket.attendee_email
      )

      get "/v1/events/#{event.id}/feedback_form/responses?page=2", headers: organizer_headers

      last_response = JSON.parse(response.body).fetch('data').first
      expect(last_response.fetch('id')).to eq(responses.first.id)
      expect(last_response.fetch('ticket')).to be_nil
      expect(last_response.fetch('answers')).to eq(question.id.to_s => 'A, B')
    end

    it 'forbids users without event update permission' do
      get "/v1/events/#{event.id}/feedback_form/responses", headers: regular_headers

      expect(response).to have_http_status(:forbidden)
    end

    it 'returns an empty page when the event has no feedback form' do
      get "/v1/events/#{event.id}/feedback_form/responses", headers: organizer_headers

      body = JSON.parse(response.body)
      expect(body.fetch('data')).to eq([])
      expect(body.fetch('pagination')).to include('total_count' => 0)
    end

    it 'searches multi-choice answers by option text, not JSON punctuation' do
      form = FeedbackForm.create!(event:, title: 'After the event')
      question = form.feedback_questions.create!(
        question_text: 'Which sessions?', question_type: :multi_choice, options: %w[Keynote Workshop]
      )
      form.feedback_responses.create!(submitted_at: Time.current)
          .feedback_answers.create!(feedback_question: question, answer_text: %w[Keynote].to_json)

      get "/v1/events/#{event.id}/feedback_form/responses", params: { q: '"' }, headers: organizer_headers
      expect(JSON.parse(response.body).fetch('data')).to be_empty

      get "/v1/events/#{event.id}/feedback_form/responses", params: { q: 'keynote' }, headers: organizer_headers
      expect(JSON.parse(response.body).fetch('data').size).to eq(1)
    end
  end

  describe 'PATCH /v1/events/:event_id/feedback_form' do
    it 'updates existing questions, creates new questions, and removes omitted questions' do
      form = FeedbackForm.create!(event:, title: 'Before')
      kept = form.feedback_questions.create!(question_text: 'Old wording', question_type: :text, position: 0)
      removed = form.feedback_questions.create!(question_text: 'Remove me', question_type: :yes_no, position: 1)

      patch "/v1/events/#{event.id}/feedback_form",
            params: {
              feedback_form: {
                title: 'After',
                feedback_questions_attributes: [
                  { id: kept.id, question_text: 'New wording', question_type: 'text', position: 0 },
                  { question_text: 'Added', question_type: 'yes_no', position: 1 }
                ]
              }
            },
            headers: organizer_headers

      expect(response).to have_http_status(:ok)
      data = JSON.parse(response.body).fetch('data')
      expect(data['title']).to eq('After')
      expect(data['questions'].map { |question| question['question_text'] }).to eq(['New wording', 'Added'])
      expect(data['questions'].map { |question| question['id'] }).not_to include(removed.id)
    end

    it 'clears options when an existing choice question changes to a non-choice type' do
      form = FeedbackForm.create!(event:, title: 'After the event')
      question = form.feedback_questions.create!(
        question_text: 'Choose one', question_type: :single_choice, options: ['A', 'B']
      )

      patch "/v1/events/#{event.id}/feedback_form",
            params: {
              feedback_form: {
                feedback_questions_attributes: [
                  { id: question.id, question_text: 'Explain', question_type: 'text' }
                ]
              }
            },
            headers: organizer_headers

      expect(response).to have_http_status(:ok)
      expect(question.reload.question_type).to eq('text')
      expect(question.options).to be_nil
    end

    it 'preserves answered questions and their answers when replacement omits them' do
      form = FeedbackForm.create!(event:, title: 'After the event')
      question = form.feedback_questions.create!(question_text: 'Rate it', question_type: :rating)
      feedback_response = form.feedback_responses.create!(submitted_at: Time.current)
      answer = feedback_response.feedback_answers.create!(feedback_question: question, answer_text: '5')

      patch "/v1/events/#{event.id}/feedback_form",
            params: { feedback_form: { title: 'After', feedback_questions_attributes: [] } },
            headers: organizer_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(question.reload).to be_present
      expect(answer.reload.answer_text).to eq('5')
      expect(form.reload.title).to eq('After the event')
    end

    it 'rolls back form and question changes when a nested question is invalid' do
      form = FeedbackForm.create!(event:, title: 'Before')
      question = form.feedback_questions.create!(question_text: 'Existing', question_type: :text)

      patch "/v1/events/#{event.id}/feedback_form",
            params: {
              feedback_form: {
                title: 'Should roll back',
                feedback_questions_attributes: [
                  { id: question.id, question_text: 'Changed', question_type: 'text' },
                  { question_text: 'Missing choices', question_type: 'single_choice', options: [] }
                ]
              }
            },
            headers: organizer_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(form.reload.title).to eq('Before')
      expect(question.reload.question_text).to eq('Existing')
    end
  end
end
