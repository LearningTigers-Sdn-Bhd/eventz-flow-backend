require 'rails_helper'

RSpec.describe 'Feedback-gated certificates', type: :request do
  let(:event) { create(:event) }
  let!(:ticket) { create(:ticket, :paid, event:, attendee_email: 'a@example.com') }
  let(:form) { FeedbackForm.create!(event:, title: 'After the event') }
  let!(:question) { form.feedback_questions.create!(question_text: 'Rate it', question_type: :rating) }
  let!(:template) { create(:certificate_template, :ready, event:) }

  def submit
    post '/v1/public/feedback_responses',
         params: { form_id: form.id, ticket_public_id: ticket.public_id,
                   answers: [{ question_id: question.id, answer_text: '5' }] }
  end

  it 'emails the certificate right after feedback when required' do
    template.update!(require_feedback: true)
    expect { submit }.to have_enqueued_job(EmailDeliveryJob).with(anything, 'CertificateMailer', 'certificate_email', anything)
    expect(JSON.parse(response.body).dig('data', 'certificate_queued')).to be(true)
  end

  it 'does nothing extra when the toggle is off' do
    expect { submit }.not_to have_enqueued_job(EmailDeliveryJob)
    expect(JSON.parse(response.body).dig('data', 'certificate_queued')).to be(false)
  end

  it 'limits the feedback_submitted audience to responders' do
    other = create(:ticket, :paid, event:, attendee_email: 'b@example.com')
    submit
    ids = SendEventCertificatesJob.recipient_scope(event, 'feedback_submitted').pluck(:id)
    expect(ids).to contain_exactly(ticket.id)
    expect(ids).not_to include(other.id)
  end

  it 'tells attendees in the thank-you email that feedback unlocks the certificate' do
    template.update!(require_feedback: true)
    event.create_event_email_setting!(thank_you_include_feedback: true)
    expect(ThankYouMailer.thank_you_email(ticket).html_part.body.to_s).to include('e-certificate will be emailed')
  end
end
