require 'rails_helper'

RSpec.describe ThankYouMailer, type: :mailer do
  describe '#feedback_reminder_email' do
    let(:event) { create(:event) }
    let(:ticket) { create(:ticket, event:, attendee_email: 'a@example.com') }

    before do
      event.create_event_email_setting!(thank_you_include_feedback: true)
      form = event.create_feedback_form!(title: 'Feedback', is_active: true)
      form.feedback_questions.create!(question_text: 'Rate us', question_type: 'rating', position: 1)
    end

    it 'is its own email, not the thank-you copy, and links to the form' do
      mail = described_class.feedback_reminder_email(ticket)
      expect(mail.subject).to include('reminder').and include(event.title)
      expect(mail.html_part.body.to_s).to include("feedback?ticket=#{ticket.public_id}")
      expect(mail.html_part.body.to_s).not_to include('Thank You for Coming')
    end
  end
end
