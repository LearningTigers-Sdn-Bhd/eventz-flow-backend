require 'rails_helper'

RSpec.describe BookingMailer, type: :mailer do
  let(:event) { create(:event, title: 'Sabah Trade Expo 2026') }
  let(:host) { create(:user, full_name: 'Jamie Host', email: 'host@example.com') }
  let(:session) do
    BusinessMatchingSession.create!(
      event: event, title: 'B2B Matchmaking', slot_duration: 30, start_time: '09:00', end_time: '17:00',
      start_date: Date.current, end_date: Date.current + 30
    )
  end
  let(:booking_data) do
    {
      'name' => 'Alice Visitor', 'email' => 'alice@example.com', 'phone' => '0123456789',
      'booking_date' => Date.current.to_s, 'booking_time' => '10:00 AM', 'location' => 'Hall A'
    }.with_indifferent_access
  end

  describe '#confirmation_email' do
    let(:mail) { described_class.confirmation_email(booking_data, session.title, event.id) }

    it 'sends to the participant with a clear subject' do
      expect(mail.to).to eq(['alice@example.com'])
      expect(mail.subject).to eq("Booking Confirmation for #{session.title}")
    end
  end

  describe '#host_confirmation_email' do
    let(:mail) { described_class.host_confirmation_email(booking_data, session.title, event.id, host) }

    it 'sends to the host, naming the participant' do
      expect(mail.to).to eq(['host@example.com'])
      expect(mail.subject).to include('Alice Visitor')
      expect(mail.body.encoded).to include('Jamie Host')
      expect(mail.body.encoded).to include('alice@example.com')
    end
  end

  describe '#reschedule_email' do
    let(:mail) { described_class.reschedule_email(booking_data, session.title, event.id, Date.current - 1, '09:00 AM') }

    it 'sends to the participant and mentions the previous time' do
      expect(mail.to).to eq(['alice@example.com'])
      expect(mail.subject).to include('Rescheduled')
      expect(mail.body.encoded).to include('09:00 AM')
    end
  end

  describe '#host_reschedule_email' do
    let(:mail) { described_class.host_reschedule_email(booking_data, session.title, event.id, host, Date.current - 1, '09:00 AM') }

    it 'sends to the host' do
      expect(mail.to).to eq(['host@example.com'])
      expect(mail.subject).to include('Rescheduled')
    end
  end

  describe '#cancellation_email' do
    let(:mail) { described_class.cancellation_email(booking_data, session.title, event.id) }

    it 'sends to the participant' do
      expect(mail.to).to eq(['alice@example.com'])
      expect(mail.subject).to include('Cancelled')
    end
  end

  describe '#host_cancellation_email' do
    let(:mail) { described_class.host_cancellation_email(booking_data, session.title, event.id, host) }

    it 'sends to the host' do
      expect(mail.to).to eq(['host@example.com'])
      expect(mail.subject).to include('Cancelled')
    end
  end

  describe '#session_reminder_email' do
    let(:mail) { described_class.session_reminder_email(booking_data, session.title, event.id) }

    it 'sends to the participant with a 1-hour reminder subject' do
      expect(mail.to).to eq(['alice@example.com'])
      expect(mail.subject).to include('starts in 1 hour')
    end
  end

  describe '#host_daily_overview_email' do
    let!(:booking_one) do
      BusinessMatchingBooking.create!(
        business_matching_session: session, host_user: host, name: 'Bob', email: 'bob@example.com',
        phone: '0111111111', booking_date: Date.current, booking_time: '02:00 PM', duration: 30, status: 'Approved'
      )
    end
    let!(:booking_two) do
      BusinessMatchingBooking.create!(
        business_matching_session: session, host_user: host, name: 'Carol', email: 'carol@example.com',
        phone: '0122222222', booking_date: Date.current, booking_time: '10:00 AM', duration: 30, status: 'Approved'
      )
    end

    let(:mail) { described_class.host_daily_overview_email(host, [booking_one, booking_two], Date.current) }

    it 'sends one digest to the host summarizing all of today\'s sessions' do
      expect(mail.to).to eq(['host@example.com'])
      expect(mail.subject).to include('2 sessions')
    end

    it 'lists every session with time and who to meet' do
      body = mail.body.encoded
      expect(body).to include('Bob')
      expect(body).to include('Carol')
      expect(body).to include('10:00 AM')
      expect(body).to include('02:00 PM')
    end
  end
end
