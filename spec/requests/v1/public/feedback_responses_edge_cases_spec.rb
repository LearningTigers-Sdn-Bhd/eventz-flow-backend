require 'rails_helper'

RSpec.describe 'Feedback response edge cases', type: :request do
  let(:event) { create(:event) }
  let!(:ticket) { create(:ticket, :paid, event:, attendee_email: 'a@example.com') }
  let(:form) { FeedbackForm.create!(event:, title: 'Survey') }

  def question(text, page:, position: 1, type: :text, required: true, options: nil, rules: [])
    form.feedback_questions.create!(
      question_text: text, question_type: type, page_number: page, position:,
      required:, options:, routing_rules: rules
    )
  end

  def submit(answers = {}, ticket_public_id = ticket.public_id)
    post '/v1/public/feedback_responses',
         params: { form_id: form.id, ticket_public_id: ticket_public_id,
                   answers: answers.map { |q, v| { question_id: q.id, answer_text: v } } }
  end

  def body = JSON.parse(response.body)

  describe 'branch that skips the unchosen alternative' do
    # Page 1 choice: A -> page 3, B -> page 4. Pages 3 and 4 each have a required question.
    let!(:choice) do
      question('Track?', page: 1, type: :single_choice, options: %w[A B], rules: [
        { 'answer' => 'A', 'action' => 'jump_to_page', 'target_page' => 3 },
        { 'answer' => 'B', 'action' => 'jump_to_page', 'target_page' => 4 }
      ])
    end
    let!(:page2) { question('Page 2 filler', page: 2, required: false) }
    let!(:page3) { question('Track A detail', page: 3) }
    let!(:page4) { question('Track B detail', page: 4) }

    it 'accepts Track A without page 4 (attendee never sees it)' do
      submit(choice => 'A', page3 => 'x')
      expect(response).to have_http_status(:created)
    end

    it 'accepts Track B' do
      submit(choice => 'B', page4 => 'y')
      expect(response).to have_http_status(:created)
    end
  end

  describe 'rule that jumps forward, natural flow otherwise' do
    # "No" skips page 2 and lands on page 3; "Yes" walks 2 then 3.
    let!(:gate) do
      question('Attended?', page: 1, type: :single_choice, options: %w[Yes No], rules: [
        { 'answer' => 'No', 'action' => 'jump_to_page', 'target_page' => 3 }
      ])
    end
    let!(:page2) { question('Session feedback', page: 2) }
    let!(:page3) { question('Overall comment', page: 3) }

    it 'does not require page 2 when No' do
      submit(gate => 'No', page3 => 'ok')
      expect(response).to have_http_status(:created)
    end

    it 'requires page 2 and 3 when Yes' do
      submit(gate => 'Yes', page2 => 'a')
      expect(response).to have_http_status(:unprocessable_content)
      submit(gate => 'Yes', page2 => 'a', page3 => 'b')
      expect(response).to have_http_status(:created)
    end
  end

  describe 'answers to unreachable questions' do
    let!(:gate) do
      question('Attended?', page: 1, type: :single_choice, options: %w[Yes No], rules: [
        { 'answer' => 'No', 'action' => 'submit', 'target_page' => nil }
      ])
    end
    let!(:page2) { question('Session feedback', page: 2) }

    it 'does not store an answer to a question the attendee could not reach' do
      submit(gate => 'No', page2 => 'sneaky')
      expect(response).to have_http_status(:created)
      expect(FeedbackAnswer.where(feedback_question: page2)).to be_empty
    end
  end

  describe 'optional branching question left blank' do
    let!(:gate) do
      question('Track?', page: 1, type: :single_choice, required: false, options: %w[A B], rules: [
        { 'answer' => 'A', 'action' => 'jump_to_page', 'target_page' => 3 }
      ])
    end
    let!(:page2) { question('Only shown after a choice', page: 2) }

    it 'still requires page 2 in multi-page mode, where the attendee walks through it' do
      submit
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'is not blocked by a section the attendee was never shown in single-page mode' do
      form.update!(display_mode: :continuous)
      submit
      expect(response).to have_http_status(:created)
    end
  end

  describe 'answer validation' do
    let!(:rating) { question('Rate', page: 1, type: :rating) }
    let!(:pick) { question('Pick', page: 1, position: 2, type: :single_choice, options: %w[A B], required: false) }
    let!(:multi) { question('Multi', page: 1, position: 3, type: :multi_choice, options: %w[A B], required: false) }

    it 'rejects out-of-range rating' do
      submit(rating => '6')
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a choice that is not an option' do
      submit(rating => '3', pick => 'Z')
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects malformed multi-choice' do
      submit(rating => '3', multi => 'A,B')
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'treats whitespace-only required text as missing' do
      text = question('Comment', page: 1, position: 4)
      submit(rating => '3', text => '   ')
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'submission gates' do
    let!(:rating) { question('Rate', page: 1, type: :rating) }

    it 'rejects a bare preview link' do
      post '/v1/public/feedback_responses', params: { form_id: form.id, answers: [] }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects a second submission for the same ticket' do
      submit(rating => '5')
      submit(rating => '4')
      expect(response).to have_http_status(:unprocessable_content)
      expect(form.feedback_responses.count).to eq(1)
    end

    it 'rejects a closed form' do
      form.update!(is_active: false)
      submit(rating => '5')
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects a ticket from another event' do
      other = create(:ticket, :paid, event: create(:event), attendee_email: 'z@example.com')
      submit({ rating => "5" }, other.public_id)
      expect(response).to have_http_status(:not_found)
    end

    it 'rejects the same question answered twice' do
      post '/v1/public/feedback_responses',
           params: { form_id: form.id, ticket_public_id: ticket.public_id,
                     answers: [{ question_id: rating.id, answer_text: '5' },
                               { question_id: rating.id, answer_text: '4' }] }
      expect(response).to have_http_status(:unprocessable_content)
    end
  end
end
