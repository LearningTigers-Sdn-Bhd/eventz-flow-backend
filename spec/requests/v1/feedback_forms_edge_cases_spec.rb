require 'rails_helper'

RSpec.describe 'Feedback form organizer edge cases', type: :request do
  let(:organizer) { create(:user, :organizer) }
  let(:event) do
    record = create(:event)
    create(:event_assignment, role: :event_admin, event: record, user: organizer)
    record
  end
  let(:headers) { { 'Authorization' => "Bearer #{JwtService.generate_tokens(organizer)[:access_token]}" } }
  let!(:form) { FeedbackForm.create!(event:, title: 'Survey') }
  let!(:choice) do
    form.feedback_questions.create!(
      question_text: 'Track?', question_type: :single_choice, options: %w[A B], page_number: 1, position: 0,
      routing_rules: [{ 'answer' => 'A', 'action' => 'jump_to_page', 'target_page' => 2 }]
    )
  end
  let!(:later) do
    form.feedback_questions.create!(question_text: 'More', question_type: :text, page_number: 2, position: 1, routing_rules: [])
  end

  def put_questions(rows)
    put "/v1/events/#{event.id}/feedback_form",
        params: { feedback_form: { feedback_questions_attributes: rows } }, headers:, as: :json
  end

  def row(question, **overrides)
    { id: question.id, question_text: question.question_text, question_type: question.question_type,
      options: question.options, required: question.required, position: question.position,
      page_number: question.page_number, routing_rules: question.routing_rules }.merge(overrides)
  end

  it 'clears routing rules when a question stops being single choice' do
    put_questions([row(choice, question_type: 'text', options: nil), row(later)])
    expect(response).to have_http_status(:ok)
    expect(choice.reload.routing_rules).to eq([])
  end

  it 'refuses to delete a question that already has answers, with a readable error' do
    ticket = create(:ticket, :paid, event:)
    response_record = form.feedback_responses.create!(ticket:, submitted_at: Time.current)
    response_record.feedback_answers.create!(feedback_question: later, answer_text: 'hi')

    put_questions([row(choice)])
    expect(response).to have_http_status(:unprocessable_content)
    expect(form.feedback_questions.count).to eq(2)
    expect(JSON.parse(response.body)['message']).to include('already have responses')
  end

  it 'rejects an oversized text answer' do
    ticket = create(:ticket, :paid, event:)
    post '/v1/public/feedback_responses',
         params: { form_id: form.id, ticket_public_id: ticket.public_id,
                   answers: [{ question_id: choice.id, answer_text: 'A' },
                             { question_id: later.id, answer_text: 'x' * 200_000 }] }
    expect(response).to have_http_status(:unprocessable_content)
  end

  describe 'conflict warning' do
    it 'returns 409 with the latest form when someone else saved first' do
      stale = JSON.parse(get("/v1/events/#{event.id}/feedback_form", headers:) && response.body).dig('data', 'updated_at')
      form.update!(title: 'Changed by a teammate')

      put "/v1/events/#{event.id}/feedback_form",
          params: { feedback_form: { title: 'Mine', expected_updated_at: stale } }, headers:, as: :json

      expect(response).to have_http_status(:conflict)
      expect(JSON.parse(response.body).dig('data', 'title')).to eq('Changed by a teammate')
      expect(form.reload.title).to eq('Changed by a teammate')
    end

    it 'saves when the form is unchanged since it was loaded, and bumps updated_at' do
      get "/v1/events/#{event.id}/feedback_form", headers: headers
      before = JSON.parse(response.body).dig('data', 'updated_at')

      put "/v1/events/#{event.id}/feedback_form",
          params: { feedback_form: { expected_updated_at: before, feedback_questions_attributes: [row(choice), row(later, question_text: 'Edited')] } },
          headers:, as: :json

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig('data', 'updated_at')).not_to eq(before)
    end

    it 'overwrites when no expected version is sent' do
      put "/v1/events/#{event.id}/feedback_form", params: { feedback_form: { title: 'Forced' } }, headers:, as: :json
      expect(response).to have_http_status(:ok)
      expect(form.reload.title).to eq('Forced')
    end
  end

  describe 'editing a form that already has responses' do
    let!(:ticket) { create(:ticket, :paid, event:) }

    before do
      r = form.feedback_responses.create!(ticket:, submitted_at: Time.current)
      r.feedback_answers.create!(feedback_question: choice, answer_text: 'A')
    end

    it 'blocks changing the answer type of an answered question' do
      put_questions([row(choice, question_type: 'text', options: nil), row(later)])
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to include("answer type can't be changed")
    end

    it 'blocks removing or renaming an option that was chosen' do
      put_questions([row(choice, options: %w[Alpha B]), row(later)])
      expect(response).to have_http_status(:unprocessable_content)
      expect(JSON.parse(response.body)['message']).to include("can't be removed or renamed")
    end

    it 'allows renaming an option nobody picked, and adding options' do
      put_questions([row(choice, options: %w[A Bee C]), row(later)])
      expect(response).to have_http_status(:ok)
    end

    it 'allows editing question text' do
      put_questions([row(choice, question_text: 'Which track?'), row(later)])
      expect(response).to have_http_status(:ok)
    end

    it 'reports response and answer counts to the organizer' do
      get "/v1/events/#{event.id}/feedback_form", headers: headers
      data = JSON.parse(response.body)['data']
      expect(data['response_count']).to eq(1)
      expect(data['questions'].find { |q| q['id'] == choice.id }['answers_count']).to eq(1)
    end
  end

  describe 'duplicate options' do
    it 'rejects options that differ only by case' do
      put_questions([row(choice, options: %w[Yes yes]), row(later)])
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'form closed mid-fill' do
    let!(:ticket) { create(:ticket, :paid, event:) }

    def submit_with(token)
      post '/v1/public/feedback_responses',
           params: { form_id: form.id, ticket_public_id: ticket.public_id, session_token: token,
                     answers: [{ question_id: choice.id, answer_text: 'B' }] }
    end

    it 'lets someone who opened the form finish after it is closed' do
      get "/v1/public/events/#{event.slug}/feedback_form", params: { ticket: ticket.public_id }
      token = JSON.parse(response.body).dig('data', 'session_token')
      form.update!(is_active: false)

      submit_with(token)
      expect(response).to have_http_status(:created)
    end

    it 'still blocks a closed form without a session' do
      form.update!(is_active: false)
      submit_with(nil)
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a token made for another form' do
      other = FeedbackForm.create!(event: create(:event), title: 'Other')
      form.update!(is_active: false)
      submit_with(FeedbackSession.issue(other))
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a tampered token' do
      form.update!(is_active: false)
      submit_with('garbage')
      expect(response).to have_http_status(:not_found)
    end
  end
end
