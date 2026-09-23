require 'rails_helper'

RSpec.describe 'V1::Tickets resend feedback email', type: :request do
  let(:org_owner) { create(:user, :org_owner) }
  let(:event) { create(:event, payment_status: :paid, start_date: 2.days.ago, end_date: 1.day.ago) }
  let(:ticket) { create(:ticket, :checked_in, event: event, attendee_email: 'a@example.com') }
  let(:url) { "/v1/events/#{event.id}/tickets/#{ticket.public_id}/resend_feedback_email" }

  before do
    event.create_event_email_setting!(thank_you_include_feedback: true)
    form = FeedbackForm.create!(event: event, title: 'Feedback')
    form.feedback_questions.create!(question_text: 'How was it?', question_type: FeedbackQuestion.question_types.keys.first)
  end

  it 'queues the thank-you email when every condition holds' do
    expect { post url, headers: auth_headers(org_owner) }.to have_enqueued_job(EmailDeliveryJob)
    expect(response).to have_http_status(:accepted)
  end

  it 'allows a ticket whose scan was missed' do
    ticket.update_columns(checked_in: false)
    expect { post url, headers: auth_headers(org_owner) }.to have_enqueued_job(EmailDeliveryJob)
  end

  it 'rejects a waiting list ticket' do
    ticket.update_columns(waiting_list: true)
    post url, headers: auth_headers(org_owner)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects before the event has ended' do
    event.update_columns(end_date: 1.day.from_now)
    post url, headers: auth_headers(org_owner)
    expect(response).to have_http_status(:unprocessable_content)
  end

  it 'rejects when the feedback link is turned off' do
    event.event_email_setting.update!(thank_you_include_feedback: false)
    post url, headers: auth_headers(org_owner)
    expect(response).to have_http_status(:unprocessable_content)
  end
end
