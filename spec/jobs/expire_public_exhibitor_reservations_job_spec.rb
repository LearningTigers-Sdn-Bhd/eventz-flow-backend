require 'rails_helper'

RSpec.describe ExpirePublicExhibitorReservationsJob, type: :job do
  it 'expires overdue unpaid reservations but preserves paid bookings' do
    expired = create(:exhibitor_kit, reservation_expires_at: 1.minute.ago,
      payment_status: :unpaid, booking_status: :active)
    paid = create(:exhibitor_kit, reservation_expires_at: 1.minute.ago,
      payment_status: :paid, booking_status: :paid)

    described_class.perform_now

    expect(expired.reload).to be_booking_expired
    expect(paid.reload).to be_booking_paid
  end

  it 'preserves payment that completes before the expiry lock is acquired' do
    kit = create(:exhibitor_kit, reservation_expires_at: 1.minute.ago,
      payment_status: :unpaid, booking_status: :active)
    allow_any_instance_of(ExhibitorKit).to receive(:with_lock).and_wrap_original do |method, &block|
      kit.update!(payment_status: :paid, booking_status: :paid, reservation_expires_at: nil)
      method.call(&block)
    end

    described_class.perform_now

    expect(kit.reload).to be_booking_paid
  end

  it 'preserves an overdue reservation while its gateway order remains active' do
    kit = create(:exhibitor_kit, reservation_expires_at: 1.minute.ago,
      payment_status: :unpaid, booking_status: :active)
    create(:exhibitor_registration_payment, exhibitor_kit: kit,
      gateway_order_id: 'order_active', order_expires_at: 10.minutes.from_now)

    described_class.perform_now

    expect(kit.reload).to be_booking_active
  end
end
