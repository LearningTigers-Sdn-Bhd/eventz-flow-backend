# frozen_string_literal: true

# A stored AI summary. Partial or failed content is never exposed as content.
class FeedbackAiSummarySerializer
  def self.serialize(summary)
    {
      id: summary.id,
      status: summary.status,
      content: summary.ready? ? summary.content : nil,
      error: summary.status == 'failed' ? summary.error : nil,
      model: summary.model_name_used,
      filters: summary.filters,
      responses_count: summary.responses_count,
      comments_count: summary.comments_count,
      generated_by: summary.generated_by&.full_name,
      created_at: summary.created_at,
      finished_at: summary.finished_at,
      stale: summary.stale?
    }
  end
end
