# frozen_string_literal: true

# Generates one stored AI summary. No automatic retries: every run costs money,
# so a failure is recorded and the org owner decides whether to run it again.
class FeedbackAiSummaryJob < ApplicationJob
  queue_as :default

  def perform(summary_id)
    summary = FeedbackAiSummary.find_by(id: summary_id)
    return unless summary&.status == 'queued'

    summary.update!(status: 'running', started_at: Time.current)
    result = FeedbackAi::Summarizer.call(summary)
    summary.update!(
      status: 'ready', content: result.content, comments_count: result.comments_count,
      responses_count: result.responses_count, finished_at: Time.current, error: nil
    )
  rescue FeedbackAi::Summarizer::Error => e
    summary&.update!(status: 'failed', error: e.message, finished_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("[FeedbackAiSummaryJob] #{e.class}: #{e.message}")
    summary&.update!(status: 'failed', error: 'Something went wrong while summarizing. Please try again.',
                     finished_at: Time.current)
  end
end
