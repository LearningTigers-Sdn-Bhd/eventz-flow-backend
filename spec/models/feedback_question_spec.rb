require 'rails_helper'

RSpec.describe FeedbackQuestion, type: :model do
  let(:form) { FeedbackForm.create!(event: create(:event), title: 'Form') }

  describe 'associations' do
    it { is_expected.to belong_to(:feedback_form) }
    it { is_expected.to have_many(:feedback_answers).dependent(:restrict_with_error) }
  end

  describe 'question type' do
    it 'accepts only the supported question types' do
      question = FeedbackQuestion.new(feedback_form: form, question_text: 'Question', question_type: 'unknown')

      expect(question).not_to be_valid
      expect(question.errors[:question_type]).to be_present
    end
  end

  describe 'choice options' do
    it 'requires a non-empty array of strings for choice questions' do
      question = FeedbackQuestion.new(
        feedback_form: form,
        question_text: 'Pick one',
        question_type: :single_choice,
        options: []
      )

      expect(question).not_to be_valid
      expect(question.errors[:options]).to be_present
    end

    it 'rejects options for non-choice questions' do
      question = FeedbackQuestion.new(
        feedback_form: form,
        question_text: 'Describe it',
        question_type: :text,
        options: ['A']
      )

      expect(question).not_to be_valid
      expect(question.errors[:options]).to be_present
    end

    it 'rejects an empty options array for non-choice questions' do
      question = FeedbackQuestion.new(
        feedback_form: form,
        question_text: 'Describe it',
        question_type: :text,
        options: []
      )

      expect(question).not_to be_valid
      expect(question.errors[:options]).to be_present
    end

    it 'accepts valid options for choice questions' do
      question = FeedbackQuestion.new(
        feedback_form: form,
        question_text: 'Pick one',
        question_type: :multi_choice,
        options: ['A', 'B']
      )

      expect(question).to be_valid
    end
  end
end
