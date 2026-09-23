require 'rails_helper'

RSpec.describe 'V1::Public::FeedbackForms', type: :request do
  let(:event) { create(:event, status: :published) }

  describe 'GET /v1/public/events/:event_slug/feedback_form' do
    it 'returns the active form and questions ordered by position without authentication' do
      form = FeedbackForm.create!(event:, title: 'After the event')
      form.feedback_questions.create!(
        question_text: 'Choose one', question_type: :single_choice, options: ['A', 'B'], position: 1
      )
      form.feedback_questions.create!(question_text: 'Rate it', question_type: :rating, position: 0)

      get "/v1/public/events/#{event.slug}/feedback_form"

      expect(response).to have_http_status(:ok)
      questions = JSON.parse(response.body).dig('data', 'questions')
      expect(questions.map { |question| question['question_text'] }).to eq(['Rate it', 'Choose one'])
      expect(questions.last['options']).to eq(['A', 'B'])
      expect(questions.first['options']).to be_nil
    end

    it 'returns not found for an inactive form' do
      FeedbackForm.create!(event:, title: 'Hidden', is_active: false)

      get "/v1/public/events/#{event.slug}/feedback_form"

      expect(response).to have_http_status(:not_found)
    end

    it 'flags when the given ticket has already responded' do
      form = FeedbackForm.create!(event:, title: 'After the event')
      ticket = create(:ticket, event:, ticket_type: create(:ticket_type, event:))
      other_ticket = create(:ticket, event:, ticket_type: ticket.ticket_type)
      form.feedback_responses.create!(ticket:, submitted_at: Time.current)

      get "/v1/public/events/#{event.slug}/feedback_form", params: { ticket: ticket.public_id }
      expect(JSON.parse(response.body).dig('data', 'already_submitted')).to be(true)

      get "/v1/public/events/#{event.slug}/feedback_form", params: { ticket: other_ticket.public_id }
      expect(JSON.parse(response.body).dig('data', 'already_submitted')).to be(false)

      get "/v1/public/events/#{event.slug}/feedback_form"
      expect(JSON.parse(response.body).dig('data', 'already_submitted')).to be(false)
    end

    it 'returns not found when the event has no form' do
      get "/v1/public/events/#{event.slug}/feedback_form"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /v1/public/feedback_responses' do
    let(:form) { FeedbackForm.create!(event:, title: 'After the event') }
    let!(:required_question) do
      form.feedback_questions.create!(question_text: 'Rate it', question_type: :rating, required: true)
    end
    let!(:optional_question) do
      form.feedback_questions.create!(question_text: 'Anything else?', question_type: :text)
    end

    it 'rejects a submission with a missing required answer' do
      form
      required_question

      ticket = create(:ticket, event:, ticket_type: create(:ticket_type, event:))

      expect do
        post '/v1/public/feedback_responses',
             params: { form_id: form.id, ticket_public_id: ticket.public_id, answers: [] }
      end.not_to change(FeedbackResponse, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['errors'].join).to include('Rate it')
    end

    it 'rejects a submission from the preview link (no ticket)' do
      expect do
        post '/v1/public/feedback_responses',
             params: { form_id: form.id, answers: [{ question_id: required_question.id, answer_text: '5' }] }
      end.not_to change(FeedbackResponse, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to include('preview only')
    end

    it 'stores the response and answers when required questions are answered' do
      ticket_type = create(:ticket_type, event:)
      ticket = create(:ticket, event:, ticket_type:)

      expect do
        post '/v1/public/feedback_responses',
             params: {
               form_id: form.id,
               ticket_id: ticket.id,
               ticket_public_id: ticket.public_id,
                answers: [
                  { question_id: required_question.id, answer_text: '5' },
                  { question_id: optional_question.id, answer_text: 'Great event' }
               ]
             }
      end.to change(FeedbackResponse, :count).by(1).and change(FeedbackAnswer, :count).by(2)

      expect(response).to have_http_status(:created)
      saved = FeedbackResponse.order(:id).last
      expect(saved.ticket_id).to eq(ticket.id)
      expect(saved.feedback_answers.pluck(:feedback_question_id, :answer_text)).to contain_exactly(
        [required_question.id, '5'],
        [optional_question.id, 'Great event']
      )
    end

    it 'rejects an out-of-range rating' do
      expect do
        post '/v1/public/feedback_responses',
             params: { form_id: form.id, answers: [{ question_id: required_question.id, answer_text: '9' }] }
      end.not_to change(FeedbackResponse, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a second response from the same ticket' do
      ticket = create(:ticket, event:, ticket_type: create(:ticket_type, event:))
      submit = lambda do
        post '/v1/public/feedback_responses',
             params: {
               form_id: form.id,
               ticket_public_id: ticket.public_id,
               answers: [{ question_id: required_question.id, answer_text: '4' }]
             }
      end

      submit.call
      expect(response).to have_http_status(:created)
      expect { submit.call }.not_to change(FeedbackResponse, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects ticket attribution without the ticket public ID' do
      ticket_type = create(:ticket_type, event:)
      ticket = create(:ticket, event:, ticket_type:)

      expect do
        post '/v1/public/feedback_responses',
             params: {
               form_id: form.id,
               ticket_id: ticket.id,
               answers: [{ question_id: required_question.id, answer_text: '5' }]
             }
      end.not_to change(FeedbackResponse, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a ticket public ID that does not match the submitted ticket ID' do
      ticket_type = create(:ticket_type, event:)
      ticket = create(:ticket, event:, ticket_type:)
      other_ticket = create(:ticket, event:, ticket_type:)

      expect do
        post '/v1/public/feedback_responses',
             params: {
               form_id: form.id,
               ticket_id: ticket.id,
               ticket_public_id: other_ticket.public_id,
               answers: [{ question_id: required_question.id, answer_text: '5' }]
             }
      end.not_to change(FeedbackResponse, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'does not create a response for a question from another form' do
      other_form = FeedbackForm.create!(event: create(:event), title: 'Other')
      other_question = other_form.feedback_questions.create!(question_text: 'Foreign', question_type: :text)
      form
      required_question

      expect do
        post '/v1/public/feedback_responses',
             params: {
               form_id: form.id,
               answers: [
                 { question_id: required_question.id, answer_text: '5' },
                 { question_id: other_question.id, answer_text: 'Invalid' }
               ]
             }
      end.not_to change(FeedbackResponse, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
