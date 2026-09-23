require 'rails_helper'

RSpec.describe FeedbackAnswer, type: :model do
  it { is_expected.to belong_to(:feedback_response) }
  it { is_expected.to belong_to(:feedback_question) }

  describe 'answer validation by question type' do
    let(:form) { FeedbackForm.create!(event: create(:event), title: 'Feedback') }
    let(:response) { form.feedback_responses.create!(submitted_at: Time.current) }

    def answer_for(type, text, options: nil)
      question = form.feedback_questions.create!(question_text: 'Q', question_type: type, options:)
      described_class.new(feedback_response: response, feedback_question: question, answer_text: text)
    end

    it 'checks ratings are 1 to 5' do
      expect(answer_for(:rating, '5')).to be_valid
      expect(answer_for(:rating, '0')).not_to be_valid
      expect(answer_for(:rating, '4.5')).not_to be_valid
    end

    it 'checks yes/no answers' do
      expect(answer_for(:yes_no, 'yes')).to be_valid
      expect(answer_for(:yes_no, 'maybe')).not_to be_valid
    end

    it 'checks choice answers against options' do
      expect(answer_for(:single_choice, 'A', options: %w[A B])).to be_valid
      expect(answer_for(:single_choice, 'C', options: %w[A B])).not_to be_valid
      expect(answer_for(:multi_choice, '["A","B"]', options: %w[A B])).to be_valid
      expect(answer_for(:multi_choice, '["C"]', options: %w[A B])).not_to be_valid
      expect(answer_for(:multi_choice, 'A', options: %w[A B])).not_to be_valid
    end

    it 'allows blank answers' do
      expect(answer_for(:rating, '')).to be_valid
    end
  end
end
