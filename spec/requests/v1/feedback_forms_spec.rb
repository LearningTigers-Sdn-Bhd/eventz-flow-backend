require 'rails_helper'

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
