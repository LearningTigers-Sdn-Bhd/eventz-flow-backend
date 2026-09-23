require 'rails_helper'

RSpec.describe FeedbackFormSummary do
  it 'returns zero-valued statistics for questions with no answers' do
    event = create(:event)
    form = FeedbackForm.create!(event:, title: 'After the event')
    rating = form.feedback_questions.create!(question_text: 'Rate it', question_type: :rating)
    choice = form.feedback_questions.create!(
      question_text: 'Choose a session', question_type: :single_choice, options: %w[Talk Workshop]
    )

    summary = described_class.call(form)
    questions = summary.fetch(:questions).index_by { |question| question.fetch(:id) }

    expect(summary).to include(total_responses: 0, last_submitted_at: nil)
    expect(questions.fetch(rating.id)).to include(
      answered_count: 0,
      average: 0.0,
      distribution: { '1' => 0, '2' => 0, '3' => 0, '4' => 0, '5' => 0 }
    )
    expect(questions.fetch(choice.id)).to include(
      answered_count: 0,
      options: [
        { label: 'Talk', count: 0, percent: 0.0 },
        { label: 'Workshop', count: 0, percent: 0.0 }
      ]
    )
  end
end
