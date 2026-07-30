require 'rails_helper'

RSpec.describe ExhibitorBookingCapacity do
  let(:event) { create(:event) }
  let(:zone) { create(:exhibitor_zone, event: event, quota: nil) }
  let(:price) { create(:exhibitor_booth_price, event: event, exhibitor_zone: zone, quota: nil) }

  context 'when the booth price has inventory' do
    it 'allows a claim while a bookable booth remains' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :available)

      expect { described_class.lock!(price, quantity: 1) }.not_to raise_error
    end

    it 'raises SoldOut when every booth is taken' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :booked)
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :blocked)

      expect { described_class.lock!(price, quantity: 1) }.to raise_error(described_class::SoldOut)
    end

    it 'ignores the quota columns' do
      price.update!(quota: 0)
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :available)

      expect { described_class.lock!(price, quantity: 1) }.not_to raise_error
    end
  end

  context 'when the booth price has no inventory' do
    it 'still enforces the quota column' do
      price.update!(quota: 0)

      expect { described_class.lock!(price, quantity: 1) }.to raise_error(described_class::SoldOut)
    end
  end

  describe '.lock_package!' do
    let(:event) { create(:event) }
    let(:booth_price) { create(:exhibitor_booth_price, event: event) }
    let(:exhibitor) { create(:exhibitor, event: event) }

    def book!(package, booking_status: :active, reservation_expires_at: nil, quantity: 1)
      create(:exhibitor_kit, event_vendor: exhibitor, exhibitor_booth_price: booth_price,
        exhibitor_package: package, booth_quantity: quantity,
        booking_status: booking_status, reservation_expires_at: reservation_expires_at)
    end

    it 'never blocks when quota is nil' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: nil)
      book!(package)

      expect { described_class.lock_package!(package, quantity: 99) }.not_to raise_error
    end

    it 'allows a booking up to the quota' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: 2)
      book!(package)

      expect { described_class.lock_package!(package, quantity: 1) }.not_to raise_error
    end

    it 'raises SoldOut past the quota' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: 2)
      book!(package)
      book!(package)

      expect { described_class.lock_package!(package, quantity: 1) }
        .to raise_error(ExhibitorBookingCapacity::SoldOut)
    end

    it 'counts paid bookings' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: 1)
      book!(package, booking_status: :paid)

      expect { described_class.lock_package!(package, quantity: 1) }
        .to raise_error(ExhibitorBookingCapacity::SoldOut)
    end

    it 'ignores expired reservations' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: 1)
      book!(package, reservation_expires_at: 1.hour.ago)

      expect { described_class.lock_package!(package, quantity: 1) }.not_to raise_error
    end

    it 'ignores cancelled bookings' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: 1)
      book!(package, booking_status: :cancelled)

      expect { described_class.lock_package!(package, quantity: 1) }.not_to raise_error
    end

    it 'excludes the booking being edited' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: 1)
      kit = book!(package)

      expect { described_class.lock_package!(package, quantity: 1, excluding: kit) }.not_to raise_error
    end

    it 'counts booth_quantity, not row count' do
      package = create(:exhibitor_package, event: event, exhibitor_booth_price: booth_price, quota: 3)
      book!(package, quantity: 3)

      expect { described_class.lock_package!(package, quantity: 1) }
        .to raise_error(ExhibitorBookingCapacity::SoldOut)
    end
  end
end
