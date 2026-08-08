require 'rails_helper'

RSpec.describe BusinessMatchingHostDailyOverviewJob, type: :job do
  let(:event) { create(:event) }
  let(:host) { create(:user, email: 'host@example.com') }
  let(:session) do
    BusinessMatchingSession.create!(
      event: event, title: 'B2B Matchmaking', slot_duration: 30, start_time: '09:00', end_time: '17:00',
      start_date: Date.current, end_date: Date.current + 1
    )
  end

  def booking_today(time: '10:00 AM', status: 'Approved')
    BusinessMatchingBooking.create!(
      business_matching_session: session, host_user: host, name: "Guest #{time}", email: 'guest@example.com',
      phone: '0123456789', booking_date: Date.current, booking_time: time, duration: 30, status: status
    )
  end

  it 'sends one digest for a host with sessions today, even with multiple bookings' do
    booking_today(time: '10:00 AM')
    booking_today(time: '02:00 PM')

    expect { described_class.new.perform }.to have_enqueued_job(EmailDeliveryJob).exactly(1).times
  end

  it 'does not send a digest to a host with no sessions today' do
    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'excludes cancelled bookings' do
    booking_today(status: 'Cancelled')

    expect { described_class.new.perform }.not_to have_enqueued_job(EmailDeliveryJob)
  end

  it 'does not send a second digest if run again the same day' do
    booking_today

    expect {
      described_class.new.perform
      described_class.new.perform
    }.to have_enqueued_job(EmailDeliveryJob).exactly(1).times
  end
end
