require 'rails_helper'

RSpec.describe 'V1::BusinessMatching::Bookings reschedule/cancel', type: :request do
  include ActiveJob::TestHelper

  let(:event) { create(:event, use_business_matching: true) }
  let(:host_user) { create(:user) }
  let(:session) do
    BusinessMatchingSession.create!(
      event: event, title: 'S', slot_duration: 30, start_time: '09:00', end_time: '17:00',
      start_date: Date.current, end_date: Date.current + 30
    )
  end
  let!(:booking) do
    BusinessMatchingBooking.create!(
      business_matching_session: session, host_user: host_user, name: 'Visitor', email: 'visitor@example.com',
      phone: '0123456789', booking_date: Date.current, booking_time: '10:00 AM', duration: 30, status: 'Approved'
    )
  end

  describe 'PATCH /v1/business_matching/bookings/:id/reschedule' do
    it 'reschedules the booking and emails both participant and host' do
      perform_enqueued_jobs do
        expect {
          patch "/v1/business_matching/bookings/#{booking.id}/reschedule",
                params: { date: (Date.current + 1).to_s, time: '11:00 AM' }
        }.to change { ActionMailer::Base.deliveries.size }.by(2)
      end

      expect(response).to have_http_status(:ok)
      expect(booking.reload.booking_time).to eq('11:00 AM')

      recipients = ActionMailer::Base.deliveries.last(2).flat_map(&:to)
      expect(recipients).to contain_exactly('visitor@example.com', host_user.email)
    end
  end

  describe 'PATCH /v1/business_matching/bookings/:id/cancel' do
    it 'cancels the booking and emails both participant and host' do
      perform_enqueued_jobs do
        expect {
          patch "/v1/business_matching/bookings/#{booking.id}/cancel"
        }.to change { ActionMailer::Base.deliveries.size }.by(2)
      end

      expect(response).to have_http_status(:ok)
      expect(booking.reload.status).to eq('Cancelled')

      recipients = ActionMailer::Base.deliveries.last(2).flat_map(&:to)
      expect(recipients).to contain_exactly('visitor@example.com', host_user.email)
    end
  end
end
