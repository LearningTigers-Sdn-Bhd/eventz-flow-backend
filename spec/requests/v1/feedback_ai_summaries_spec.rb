require 'rails_helper'

RSpec.describe 'Feedback AI summaries', type: :request do
  let(:owner) { create(:user, :org_owner) }
  let(:organizer) { create(:user, :organizer) }
  let(:member) { create(:user, :member) }
  let(:event) do
    record = create(:event, start_date: 5.days.ago, end_date: 2.days.ago)
    create(:event_assignment, role: :event_admin, event: record, user: organizer)
    record
  end
  let(:base) { "/v1/events/#{event.id}/feedback_form/ai_summary" }
  let!(:form) { FeedbackForm.create!(event:, title: 'Survey') }
  let!(:comment_q) do
    form.feedback_questions.create!(question_text: 'Comments', question_type: :text, required: false, position: 0,
                                    routing_rules: [])
  end

  def headers_for(user)
    { 'Authorization' => "Bearer #{JwtService.generate_tokens(user)[:access_token]}" }
  end

  def json = JSON.parse(response.body)

  def add_comment(text = 'Great day overall', at: Time.current)
    r = form.feedback_responses.create!(ticket: create(:ticket, :paid, event:), submitted_at: at)
    r.feedback_answers.create!(feedback_question: comment_q, answer_text: text)
  end

  def configure_ai!
    integration = AiIntegration.create!(provider: 'OpenAI', api_url: 'https://api.openai.com/v1', api_key: 'sk-test')
    AiModel.create!(ai_integration: integration, model_id: 'gpt-x', display_name: 'GPT X', is_default: true)
  end

  describe 'GET' do
    it 'tells an org_owner what they can do and which provider will be used' do
      configure_ai!
      get base, headers: headers_for(owner)
      expect(response).to have_http_status(:ok)
      expect(json['data']).to include('can_generate' => true, 'configured' => true, 'provider' => 'OpenAI', 'model' => 'GPT X')
    end

    it 'lets an event organizer read but not trigger, without revealing provider details' do
      configure_ai!
      get base, headers: headers_for(organizer)
      expect(response).to have_http_status(:ok)
      expect(json['data']).to include('can_generate' => false, 'provider' => nil, 'model' => nil)
    end

    it 'shows the latest summary content only when it is ready' do
      form.feedback_ai_summaries.create!(status: 'ready', content: { 'overview' => 'Good' }, model_name_used: 'GPT X',
                                         started_at: 1.hour.ago, comments_count: 4, generated_by: owner)
      get base, headers: headers_for(organizer)
      summary = json['data']['summary']
      expect(summary).to include('status' => 'ready', 'comments_count' => 4, 'stale' => false, 'model' => 'GPT X')
      expect(summary['content']).to eq('overview' => 'Good')
    end

    it 'hides partial content and surfaces the error for a failed run' do
      form.feedback_ai_summaries.create!(status: 'failed', error: 'The AI provider took too long to respond', content: { 'x' => 1 })
      get base, headers: headers_for(organizer)
      expect(json['data']['summary']).to include('status' => 'failed', 'content' => nil,
                                                 'error' => 'The AI provider took too long to respond')
    end

    it 'flags a stale summary' do
      form.feedback_ai_summaries.create!(status: 'ready', content: {}, started_at: 1.hour.ago)
      add_comment(at: 5.minutes.ago)
      get base, headers: headers_for(owner)
      expect(json['data']['summary']['stale']).to be(true)
    end

    it 'rejects someone with no access to the event' do
      get base, headers: headers_for(member)
      expect(response).to have_http_status(:forbidden)
    end

    it '404s without a form' do
      form.destroy
      get base, headers: headers_for(owner)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST' do
    before { add_comment }

    it 'lets an org_owner queue a summary' do
      configure_ai!
      expect { post base, headers: headers_for(owner) }.to have_enqueued_job(FeedbackAiSummaryJob)
      expect(response).to have_http_status(:accepted)
      summary = form.feedback_ai_summaries.last
      expect(summary).to have_attributes(status: 'queued', generated_by: owner, model_name_used: 'GPT X')
      expect(json['data']['summary']).to include('status' => 'queued')
    end

    it 'forbids an event admin, even one who can manage the event' do
      configure_ai!
      expect { post base, headers: headers_for(organizer) }.not_to have_enqueued_job(FeedbackAiSummaryJob)
      expect(response).to have_http_status(:forbidden)
      expect(form.feedback_ai_summaries.count).to eq(0)
    end

    it 'forbids other users and unauthenticated calls' do
      configure_ai!
      post base, headers: headers_for(member)
      expect(response).to have_http_status(:forbidden)
      post base
      expect(response).to have_http_status(:unauthorized)
    end

    it 'explains when no AI provider or default model is set up' do
      post base, headers: headers_for(owner)
      expect(response).to have_http_status(:unprocessable_content)
      expect(json['message']).to include('not set up')
    end

    it 'refuses a second run while one is in progress' do
      configure_ai!
      form.feedback_ai_summaries.create!(status: 'running', created_at: 2.minutes.ago)
      post base, headers: headers_for(owner)
      expect(response).to have_http_status(:conflict)
    end

    it 'enforces a cooldown between runs' do
      configure_ai!
      form.feedback_ai_summaries.create!(status: 'ready', created_at: 10.seconds.ago)
      post base, headers: headers_for(owner)
      expect(response).to have_http_status(:too_many_requests)
      expect(json['message']).to match(/wait \d+ seconds/)
    end

    it 'enforces a daily limit per form' do
      configure_ai!
      FeedbackAiSummary::DAILY_LIMIT.times do |i|
        form.feedback_ai_summaries.create!(status: 'ready', created_at: (2 + i).hours.ago)
      end
      post base, headers: headers_for(owner)
      expect(response).to have_http_status(:too_many_requests)
      expect(json['message']).to include('daily limit')
    end

    it 'does not run a summary when there are no comments' do
      configure_ai!
      FeedbackAnswer.delete_all
      post base, headers: headers_for(owner)
      expect(response).to have_http_status(:unprocessable_content)
      expect(json['message']).to include('no comments')
    end

    it 'stores the filters the summary was asked for' do
      configure_ai!
      vip = create(:ticket_type, event:, name: 'VIP')
      ticket = create(:ticket, :paid, event:, ticket_type: vip)
      r = form.feedback_responses.create!(ticket:, submitted_at: Time.current)
      r.feedback_answers.create!(feedback_question: comment_q, answer_text: 'VIP lounge was lovely')
      post base, params: { ticket_type_id: vip.id, from: '2026-01-01' }, headers: headers_for(owner)
      expect(form.feedback_ai_summaries.last.filters).to eq('ticket_type_id' => vip.id.to_s, 'from' => '2026-01-01')
    end

    it 'never sends the API key back to the client' do
      configure_ai!
      post base, headers: headers_for(owner)
      expect(response.body).not_to include('sk-test')
      get base, headers: headers_for(owner)
      expect(response.body).not_to include('sk-test')
    end
  end
end
