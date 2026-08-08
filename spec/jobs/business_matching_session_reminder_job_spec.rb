require 'rails_helper'

RSpec.describe BusinessMatchingSessionReminderJob, type: :job do
  let(:event) { create(:event) }
  let(:host) { create(:user) }
  let(:session) do
    BusinessMatchingSession.create!(
      event: event, title: 'B2B Matchmaking', slot_duration: 30, start_time: '09:00', end_time: '23:59',
      start_date: Date.current, end_date: Date.current + 1
    )
  end

  def booking_starting_in(minutes_from_now)
    start_at = Time.current + minutes_from_now.minutes
    BusinessMatchingBooking.create!(
      business_matching_session: session, host_user: host, name: 'Alice', email: 'alice@example.com',
      phone: '0123456789', booking_date: start_at.to_date, booking_time: start_at.strftime('%I:%M %p'),
      duration: 30, status: 'Approved'
    )
  end

  it 'reminds a participant whose session starts in about an hour' do
    booking_starting_in(60)

    expect { described_class.new.perform }.to have_enqueued_job(EmailDeliveryJob)
  end

  it 'does not remind a participant whose session is much further away' do
    booking_starting_in(300)

    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'does not remind a participant whose session already started' do
    booking_starting_in(-10)

    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'skips cancelled bookings' do
    booking = booking_starting_in(60)
    booking.update_column(:status, 'Cancelled')

    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'does not send a duplicate reminder for the same booking' do
    booking_starting_in(60)

    expect {
      described_class.new.perform
      described_class.new.perform
    }.to have_enqueued_job(EmailDeliveryJob).exactly(1).times
  end

  it 'logs the reminder so it is not resent by a later run' do
    booking = booking_starting_in(60)
    described_class.new.perform

    expect(BusinessMatchingReminderLog.exists?(business_matching_booking_id: booking.id, reminder_type: '1_hour')).to be true
  end
end
