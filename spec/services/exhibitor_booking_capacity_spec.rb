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
end
