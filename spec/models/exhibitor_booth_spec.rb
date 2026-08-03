require 'rails_helper'

RSpec.describe ExhibitorBooth do
  let(:event) { create(:event) }
  let(:zone) { create(:exhibitor_zone, event: event) }
  let(:price) { create(:exhibitor_booth_price, event: event, exhibitor_zone: zone) }

  describe 'normalization' do
    it 'strips and upcases the number' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: '  s045 ')
      expect(booth.number).to eq('S045')
    end
  end

  describe 'validations' do
    it 'rejects a duplicate number within the same event' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045')
      duplicate = build(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 's045')

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:number]).to be_present
    end

    it 'allows the same number in a different event' do
      create(:exhibitor_booth, event: event, exhibitor_booth_price: price, number: 'S045')
      other_event = create(:event)
      other_price = create(:exhibitor_booth_price, event: other_event)

      expect(build(:exhibitor_booth, event: other_event, exhibitor_booth_price: other_price,
        number: 'S045')).to be_valid
    end

    it 'rejects a booth price belonging to another event' do
      foreign_price = create(:exhibitor_booth_price, event: create(:event))
      booth = build(:exhibitor_booth, event: event, exhibitor_booth_price: foreign_price, number: 'S001')

      expect(booth).not_to be_valid
      expect(booth.errors[:exhibitor_booth_price_id]).to include('must belong to the same event')
    end
  end

  describe '.bookable' do
    let(:exhibitor) { create(:exhibitor, event: event) }

    def kit_with(booking_status, reservation_expires_at: nil)
      create(:exhibitor_kit, event_vendor: exhibitor, booking_status: booking_status,
        reservation_expires_at: reservation_expires_at)
    end

    it 'includes available booths' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :available)
      expect(described_class.bookable).to include(booth)
    end

    it 'excludes blocked and booked booths' do
      blocked = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :blocked)
      booked = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :booked)

      expect(described_class.bookable).not_to include(blocked, booked)
    end

    it 'excludes a booth reserved by an active kit with no expiry' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :reserved,
        exhibitor_kit: kit_with(:active))

      expect(described_class.bookable).not_to include(booth)
    end

    it 'excludes a booth reserved by an active kit whose hold has not lapsed' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :reserved,
        exhibitor_kit: kit_with(:active, reservation_expires_at: 1.hour.from_now))

      expect(described_class.bookable).not_to include(booth)
    end

    it 'includes a booth reserved by an active kit whose hold has lapsed' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :reserved,
        exhibitor_kit: kit_with(:active, reservation_expires_at: 1.hour.ago))

      expect(described_class.bookable).to include(booth)
    end

    it 'includes a booth reserved by a cancelled or expired kit' do
      cancelled = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :reserved,
        exhibitor_kit: kit_with(:cancelled))
      expired = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :reserved,
        exhibitor_kit: kit_with(:expired))

      expect(described_class.bookable).to include(cancelled, expired)
    end

    it 'includes a booth marked reserved with no kit attached' do
      booth = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :reserved,
        exhibitor_kit: nil)

      expect(described_class.bookable).to include(booth)
    end
  end

  describe '#bookable?' do
    it 'mirrors the scope' do
      available = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :available)
      blocked = create(:exhibitor_booth, event: event, exhibitor_booth_price: price, status: :blocked)

      expect(available.bookable?).to be(true)
      expect(blocked.bookable?).to be(false)
    end
  end
end
