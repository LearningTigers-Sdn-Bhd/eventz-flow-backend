require 'rails_helper'

RSpec.describe FeedbackAiSummaryJob, type: :job do
  let(:event) { create(:event) }
  let(:form) { FeedbackForm.create!(event:, title: 'Survey') }
  let(:summary) { form.feedback_ai_summaries.create! }
  let(:result) do
    FeedbackAi::Summarizer::Result.new(content: { 'overview' => 'ok' }, comments_count: 3, responses_count: 5, truncated: false)
  end

  it 'stores the summary and marks it ready' do
    allow(FeedbackAi::Summarizer).to receive(:call).and_return(result)
    described_class.perform_now(summary.id)
    summary.reload
    expect(summary).to have_attributes(status: 'ready', comments_count: 3, responses_count: 5, error: nil)
    expect(summary.content).to eq('overview' => 'ok')
    expect(summary.started_at).to be_present
    expect(summary.finished_at).to be_present
  end

  it 'records a friendly failure and does not retry' do
    allow(FeedbackAi::Summarizer).to receive(:call).and_raise(FeedbackAi::Summarizer::Error, 'The AI provider took too long to respond')
    expect { described_class.perform_now(summary.id) }.not_to have_enqueued_job(described_class)
    expect(summary.reload).to have_attributes(status: 'failed', error: 'The AI provider took too long to respond')
  end

  it 'hides unexpected errors behind a generic message' do
    allow(FeedbackAi::Summarizer).to receive(:call).and_raise(StandardError, 'database password is hunter2')
    described_class.perform_now(summary.id)
    expect(summary.reload.error).to eq('Something went wrong while summarizing. Please try again.')
    expect(summary.error).not_to include('hunter2')
  end

  it 'ignores a summary that is no longer queued (no double runs)' do
    summary.update!(status: 'ready')
    expect(FeedbackAi::Summarizer).not_to receive(:call)
    described_class.perform_now(summary.id)
  end

  it 'ignores a missing summary' do
    expect { described_class.perform_now(0) }.not_to raise_error
  end
end
