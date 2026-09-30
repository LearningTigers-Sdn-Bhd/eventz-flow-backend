require 'rails_helper'

RSpec.describe FeedbackAiSummary, type: :model do
  let(:event) { create(:event) }
  let(:form) { FeedbackForm.create!(event:, title: 'Survey') }

  def respond_at(time)
    form.feedback_responses.create!(ticket: create(:ticket, :paid, event:), submitted_at: time)
  end

  it 'rejects unknown statuses' do
    expect(form.feedback_ai_summaries.build(status: 'done')).not_to be_valid
  end

  it 'counts only recent queued or running summaries as active' do
    form.feedback_ai_summaries.create!(status: 'ready')
    expect(form.feedback_ai_summaries.active).to be_empty
    running = form.feedback_ai_summaries.create!(status: 'running')
    expect(form.feedback_ai_summaries.active).to contain_exactly(running)
    running.update_columns(created_at: 30.minutes.ago) # a job that never reported back
    expect(form.feedback_ai_summaries.active).to be_empty
  end

  describe '#stale?' do
    let(:summary) { form.feedback_ai_summaries.create!(status: 'ready', started_at: 1.hour.ago) }

    it 'is false when nothing new has arrived' do
      respond_at(2.hours.ago)
      expect(summary).not_to be_stale
    end

    it 'is true once a response arrives after the summary started' do
      respond_at(10.minutes.ago)
      expect(summary).to be_stale
    end

    it 'only looks at responses inside the summary filters' do
      other_type = create(:ticket_type, event:, name: 'VIP')
      summary.update!(filters: { 'ticket_type_id' => other_type.id.to_s })
      respond_at(10.minutes.ago) # a different ticket type
      expect(summary).not_to be_stale
    end

    it 'is false for summaries that are not ready' do
      expect(form.feedback_ai_summaries.create!(status: 'failed', started_at: 1.hour.ago)).not_to be_stale
    end
  end

  it 'is deleted with its form' do
    form.feedback_ai_summaries.create!
    expect { form.destroy }.to change(described_class, :count).by(-1)
  end
end
