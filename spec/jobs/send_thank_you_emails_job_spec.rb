require 'rails_helper'

RSpec.describe SendThankYouEmailsJob, type: :job do
  let(:event) do
    create(:event, status: :published, start_date: 1.day.ago, end_date: 3.hours.ago)
  end

  before do
    create(:ticket, :checked_in, event: event, attendee_email: 'a@example.com')
    create(:ticket, :checked_in, event: event, attendee_email: 'A@example.com') # same person
    create(:ticket, :checked_in, event: event, attendee_email: 'b@example.com')
    create(:ticket, event: event, attendee_email: 'noshow@example.com')
  end

  it 'sends one email per checked-in address, once' do
    expect { described_class.new.perform }.to have_enqueued_job(EmailDeliveryJob).twice
    expect(event.reload.thank_you_sent_at).to be_present
    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'skips events that ended too recently or too long ago' do
    event.update_columns(end_date: 30.minutes.ago)
    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
    event.update_columns(end_date: 10.days.ago)
    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'respects the thank_you category toggle' do
    event.create_event_email_setting!(disabled_categories: ['thank_you'])
    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end
end

RSpec.describe ThankYouMailer, type: :mailer do
  let(:event) { create(:event) }
  let(:ticket) { create(:ticket, :checked_in, event: event, attendee_email: 'a@example.com') }

  it 'omits the feedback link by default and includes it when opted in with an active form' do
    expect(described_class.thank_you_email(ticket).html_part.body.to_s).not_to include('Share Your Feedback')

    event.create_event_email_setting!(thank_you_include_feedback: true)
    form = FeedbackForm.create!(event: event, title: 'Feedback')
    expect(described_class.thank_you_email(ticket.reload).html_part.body.to_s).not_to include('Share Your Feedback')

    form.feedback_questions.create!(question_text: 'How was it?', question_type: FeedbackQuestion.question_types.keys.first)
    body = described_class.thank_you_email(ticket.reload).html_part.body.to_s
    expect(body).to include('Share Your Feedback', "feedback?ticket=#{ticket.public_id}")
  end
end

RSpec.describe Event, '.ended_before' do
  it 'treats a midnight end date as the end of that day' do
    midnight = create(:event, start_date: Time.zone.today.beginning_of_day, end_date: Time.zone.today.beginning_of_day)
    timed = create(:event, start_date: 3.hours.ago, end_date: 1.hour.ago)

    ids = described_class.ended_before(Time.current).pluck(:id)
    expect(ids).to include(timed.id)
    expect(ids).not_to include(midnight.id)
    expect(midnight.ended?).to be(false)

    travel_to(Time.zone.tomorrow.beginning_of_day + 1.minute) do
      expect(described_class.ended_before(Time.current).pluck(:id)).to include(midnight.id)
      expect(midnight.ended?).to be(true)
    end
  end
end
