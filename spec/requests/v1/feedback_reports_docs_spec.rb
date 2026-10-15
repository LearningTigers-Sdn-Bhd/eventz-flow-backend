require 'swagger_helper'

# API documentation (rswag) for the organizer feedback insight endpoints.
# Behaviour is covered in more depth by feedback_reports_spec.rb and
# feedback_ai_summaries_spec.rb; these examples keep the OpenAPI doc accurate.
RSpec.describe 'V1::FeedbackReports', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:regular_user) { create(:user, :member) }
  let(:event) { create(:event, start_date: 5.days.ago, end_date: 2.days.ago) }
  let(:event_id) { event.id }
  let!(:form) { FeedbackForm.create!(event:, title: 'After the event') }
  let!(:rating) do
    form.feedback_questions.create!(question_text: 'Rate it', question_type: :rating, position: 0, routing_rules: [])
  end
  let!(:comment_question) do
    form.feedback_questions.create!(question_text: 'Comments', question_type: :text, required: false, position: 1,
                                    routing_rules: [])
  end
  let!(:attendee) do
    create(:ticket, :paid, event:, attendee_name: 'Aisyah Tan', attendee_email: 'aisyah@example.com',
                           checked_in: true, check_in_at: Time.current)
  end
  let!(:waiting) do
    create(:ticket, :paid, event:, attendee_name: 'Wei Jie Lim', attendee_email: 'weijie@example.com',
                           checked_in: true, check_in_at: Time.current)
  end
  let(:Authorization) { "Bearer #{JwtService.generate_tokens(org_owner)[:access_token]}" }

  before do
    response = form.feedback_responses.create!(ticket: attendee, submitted_at: Time.current)
    response.feedback_answers.create!(feedback_question: rating, answer_text: '4')
    response.feedback_answers.create!(feedback_question: comment_question, answer_text: 'Loved the keynote')
    event.create_event_email_setting!(thank_you_include_feedback: true)
  end

  # Filters shared by the summary, comments, non-responders, export and AI summary endpoints.
  def self.shared_filters
    parameter name: :ticket_type_id, in: :query, type: :integer, required: false, description: 'Only this ticket type'
    parameter name: :from, in: :query, type: :string, required: false, description: 'Submitted on or after (YYYY-MM-DD)'
    parameter name: :to, in: :query, type: :string, required: false, description: 'Submitted on or before (YYYY-MM-DD)'
  end

  path '/v1/events/{event_id}/feedback_form/comments' do
    parameter name: 'event_id', in: :path, type: :integer, description: 'event_id'
    shared_filters
    parameter name: :q, in: :query, type: :string, required: false, description: 'Search comment text or attendee'
    parameter name: :question_id, in: :query, type: :integer, required: false, description: 'Only this text question'
    parameter name: :max_rating, in: :query, type: :number, required: false,
              description: 'Only responses whose average rating is at or below this (find unhappy attendees)'
    parameter name: :page, in: :query, type: :integer, required: false
    parameter name: :per_page, in: :query, type: :integer, required: false

    get('list comments') do
      tags 'Feedback Reports'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Written answers, newest first, each with the attendee and that response\'s average rating.'

      response(200, 'successful') do
        run_test!
      end

      response(403, 'forbidden') do
        let(:Authorization) { "Bearer #{JwtService.generate_tokens(regular_user)[:access_token]}" }
        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/feedback_form/non_responders' do
    parameter name: 'event_id', in: :path, type: :integer, description: 'event_id'
    parameter name: :ticket_type_id, in: :query, type: :integer, required: false
    parameter name: :q, in: :query, type: :string, required: false, description: 'Search name or email'
    parameter name: :page, in: :query, type: :integer, required: false
    parameter name: :per_page, in: :query, type: :integer, required: false

    get('list attendees who have not responded') do
      tags 'Feedback Reports'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Checked-in, still-valid tickets (not cancelled, refunded or waitlisted) with no response yet.'

      response(200, 'successful') do
        run_test!
      end

      response(403, 'forbidden') do
        let(:Authorization) { "Bearer #{JwtService.generate_tokens(regular_user)[:access_token]}" }
        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/feedback_form/remind' do
    parameter name: 'event_id', in: :path, type: :integer, description: 'event_id'

    post('remind attendees to give feedback') do
      tags 'Feedback Reports'
      consumes 'application/json'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Re-sends the thank-you email (with the feedback link) to non-responders. ' \
                  'Anyone emailed in the last 24 hours is skipped. Only after the event has ended.'
      parameter name: :body, in: :body, required: true, schema: {
        type: :object,
        properties: {
          ticket_ids: { type: :array, items: { type: :string }, description: 'Ticket public IDs' },
          all: { type: :boolean, description: 'Remind every non-responder (up to 500)' }
        }
      }

      response(202, 'accepted') do
        let(:body) { { ticket_ids: [waiting.public_id] } }
        run_test!
      end

      response(422, 'event has not ended or the feedback email is off') do
        before { event.update!(end_date: 2.days.from_now) }
        let(:body) { { all: true } }
        run_test!
      end

      response(403, 'forbidden') do
        let(:Authorization) { "Bearer #{JwtService.generate_tokens(regular_user)[:access_token]}" }
        let(:body) { { all: true } }
        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/feedback_form/export_data' do
    parameter name: 'event_id', in: :path, type: :integer, description: 'event_id'
    shared_filters

    get('export feedback data') do
      tags 'Feedback Reports'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Everything needed to build CSV, Excel and PDF files: form, summary, questions, responses and ' \
                  'comments. Limited to 10,000 responses (422 above that; narrow the filters).'

      response(200, 'successful') do
        run_test!
      end

      response(403, 'forbidden') do
        let(:Authorization) { "Bearer #{JwtService.generate_tokens(regular_user)[:access_token]}" }
        run_test!
      end
    end
  end

  path '/v1/events/{event_id}/feedback_form/ai_summary' do
    parameter name: 'event_id', in: :path, type: :integer, description: 'event_id'

    get('read the latest AI summary') do
      tags 'Feedback Reports'
      produces 'application/json'
      security [bearerAuth: []]
      description 'The latest stored AI summary plus `can_generate` (true only for an org_owner) and whether an ' \
                  'AI provider is configured. Provider details are only returned to an org_owner.'

      response(200, 'successful') do
        run_test!
      end

      response(403, 'forbidden') do
        let(:Authorization) { "Bearer #{JwtService.generate_tokens(regular_user)[:access_token]}" }
        run_test!
      end
    end

    post('generate an AI summary') do
      tags 'Feedback Reports'
      produces 'application/json'
      security [bearerAuth: []]
      description 'Org owner only. Queues a background job that summarizes the written comments with the ' \
                  'organization\'s default AI model. Only comment text is sent (no names or emails). ' \
                  'One run at a time per form, 60 second cooldown, 10 per form per day.'
      shared_filters

      response(202, 'accepted') do
        before do
          integration = AiIntegration.create!(provider: 'OpenAI', api_url: 'https://api.openai.com/v1', api_key: 'sk-test')
          AiModel.create!(ai_integration: integration, model_id: 'gpt-x', display_name: 'GPT X', is_default: true)
        end
        run_test!
      end

      response(422, 'AI is not set up, or there are no comments') do
        run_test!
      end

      response(403, 'only an org_owner can generate a summary') do
        # An event admin can manage the event but still may not trigger AI.
        let(:event_admin) { create(:user, :organizer) }
        let(:Authorization) { "Bearer #{JwtService.generate_tokens(event_admin)[:access_token]}" }
        before { create(:event_assignment, role: :event_admin, event:, user: event_admin) }
        run_test!
      end
    end
  end
end
