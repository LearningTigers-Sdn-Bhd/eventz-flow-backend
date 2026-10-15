require 'rails_helper'

RSpec.describe FeedbackForm, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to have_many(:feedback_questions).dependent(:destroy) }
    it { is_expected.to have_many(:feedback_responses).dependent(:destroy) }

    it 'is a dependent one-to-one association from Event' do
      association = Event.reflect_on_association(:feedback_form)

      expect(association.macro).to eq(:has_one)
      expect(association.options[:dependent]).to eq(:destroy)
    end
  end

  describe 'event uniqueness' do
    it 'allows one form per event' do
      event = create(:event)
      FeedbackForm.create!(event:, title: 'First form')
      duplicate = FeedbackForm.new(event:, title: 'Second form')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:event_id]).to be_present
    end
  end

  it 'destroys response history when the parent event is destroyed' do
    event = create(:event)
    form = FeedbackForm.create!(event:, title: 'After the event')
    question = form.feedback_questions.create!(question_text: 'Rate it', question_type: :rating)
    ticket_type = create(:ticket_type, event:)
    ticket = create(:ticket, event:, ticket_type:)
    response = form.feedback_responses.create!(ticket:, submitted_at: Time.current)
    response.feedback_answers.create!(feedback_question: question, answer_text: '5')

    expect { event.delete }
      .to change(Event, :count).by(-1)
      .and change(Ticket, :count).by(-1)
      .and change(FeedbackForm, :count).by(-1)
      .and change(FeedbackQuestion, :count).by(-1)
      .and change(FeedbackResponse, :count).by(-1)
      .and change(FeedbackAnswer, :count).by(-1)
  end
end
