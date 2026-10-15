require 'rails_helper'

RSpec.describe 'V1::BusinessMatching::Bookings approve', type: :request do
  include ActiveJob::TestHelper

  let(:event) { create(:event, use_business_matching: true, business_matching_auto_approve_bookings: false) }
  let(:host_user) { create(:user) }
  let(:admin) { create(:user) }
  let(:session) do
    BusinessMatchingSession.create!(
      event: event, title: 'S', slot_duration: 30, start_time: '09:00', end_time: '17:00',
      start_date: Date.current, end_date: Date.current + 30
    )
  end
  let!(:booking) do
    BusinessMatchingBooking.create!(
      business_matching_session: session, host_user: host_user, name: 'Visitor', email: 'visitor@example.com',
      phone: '0123456789', booking_date: Date.current, booking_time: '10:00 AM', duration: 30, status: 'Pending'
    )
  end

  before do
    create(:event_assignment, event: event, user: host_user, role: :business_host)
    BusinessHostAssignment.create!(user: host_user, event: event, business_matching_event_id: session.id.to_s)
    create(:event_assignment, event: event, user: admin, role: :event_admin)
  end

  it 'approves a pending booking and emails the booker that it is confirmed' do
    perform_enqueued_jobs do
      expect {
        patch "/v1/business_matching/bookings/#{booking.id}/approve", headers: auth_headers(admin)
      }.to change { ActionMailer::Base.deliveries.size }.by(1)
    end

    expect(response).to have_http_status(:ok)
    expect(booking.reload.status).to eq('Approved')

    email = ActionMailer::Base.deliveries.last
    expect(email.to).to eq(['visitor@example.com'])
    expect(email.subject).to include('Is Confirmed')
  end

  it 'lets the assigned host approve their own booking' do
    patch "/v1/business_matching/bookings/#{booking.id}/approve", headers: auth_headers(host_user)

    expect(response).to have_http_status(:ok)
    expect(booking.reload.status).to eq('Approved')
  end

  it 'is a no-op for an already-approved booking so the booker is not emailed twice' do
    booking.update!(status: 'Approved')

    perform_enqueued_jobs do
      expect {
        patch "/v1/business_matching/bookings/#{booking.id}/approve", headers: auth_headers(admin)
      }.not_to change { ActionMailer::Base.deliveries.size }
    end

    expect(response).to have_http_status(:ok)
  end

  it 'refuses to approve a cancelled booking' do
    booking.update!(status: 'Cancelled')

    patch "/v1/business_matching/bookings/#{booking.id}/approve", headers: auth_headers(admin)

    expect(response).to have_http_status(:unprocessable_entity)
    expect(booking.reload.status).to eq('Cancelled')
  end

  it 'rejects an unauthenticated request' do
    patch "/v1/business_matching/bookings/#{booking.id}/approve"

    expect(response).to have_http_status(:unauthorized)
    expect(booking.reload.status).to eq('Pending')
  end

  it 'rejects a user with no role on the event' do
    outsider = create(:user)

    patch "/v1/business_matching/bookings/#{booking.id}/approve", headers: auth_headers(outsider)

    expect(response).to have_http_status(:forbidden)
    expect(booking.reload.status).to eq('Pending')
  end

  it '404s for an unknown booking' do
    patch "/v1/business_matching/bookings/#{SecureRandom.uuid}/approve", headers: auth_headers(admin)

    expect(response).to have_http_status(:not_found)
  end
end
