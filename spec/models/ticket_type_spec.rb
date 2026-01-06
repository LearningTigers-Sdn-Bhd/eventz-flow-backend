require 'rails_helper'

RSpec.describe TicketType, type: :model do
  describe 'associations' do
    it { should belong_to(:event).optional }
    it { should have_many(:tickets) }
  end

  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:max_per_order) }
    it { should validate_numericality_of(:max_per_order).is_greater_than_or_equal_to(1) }
  end

  describe 'enums' do
    it { should define_enum_for(:status).with_values(draft: 0, published: 1, archived: 2) }
  end

  describe 'scopes' do
    let(:event) { create(:event) }
    let!(:global_ticket_type) { create(:ticket_type, event: nil, status: :published, hidden: false) }
    let!(:event_ticket_type) { create(:ticket_type, event: event, status: :published, hidden: false) }
    let!(:hidden_ticket_type) { create(:ticket_type, event: event, status: :published, hidden: true) }
    let!(:draft_ticket_type) { create(:ticket_type, event: event, status: :draft) }

    describe '.global' do
      it 'returns ticket types without an event' do
        expect(TicketType.global).to include(global_ticket_type)
        expect(TicketType.global).not_to include(event_ticket_type)
      end
    end

    describe '.event_specific' do
      it 'returns ticket types with an event' do
        expect(TicketType.event_specific).to include(event_ticket_type)
        expect(TicketType.event_specific).not_to include(global_ticket_type)
      end
    end

    describe '.publicly_available' do
      it 'returns published and non-hidden ticket types' do
        expect(TicketType.publicly_available).to include(global_ticket_type)
        expect(TicketType.publicly_available).to include(event_ticket_type)
        expect(TicketType.publicly_available).not_to include(hidden_ticket_type)
        expect(TicketType.publicly_available).not_to include(draft_ticket_type)
      end
    end

    describe '.on_sale' do
      let!(:on_sale_ticket) { create(:ticket_type, event: event, sale_starts_at: 1.day.ago, sale_ends_at: 1.day.from_now) }
      let!(:future_sale_ticket) { create(:ticket_type, event: event, sale_starts_at: 1.day.from_now, sale_ends_at: 2.days.from_now) }
      let!(:past_sale_ticket) { create(:ticket_type, event: event, sale_starts_at: 2.days.ago, sale_ends_at: 1.day.ago) }

      it 'returns ticket types currently on sale' do
        expect(TicketType.on_sale).to include(on_sale_ticket)
        expect(TicketType.on_sale).not_to include(future_sale_ticket)
        expect(TicketType.on_sale).not_to include(past_sale_ticket)
      end

      it 'includes ticket types with nil sale dates' do
        expect(TicketType.on_sale).to include(global_ticket_type)
      end
    end
  end

  describe '#available?' do
    let(:event) { create(:event) }

    it 'returns true for published, non-hidden, on-sale ticket types' do
      ticket_type = create(:ticket_type, event: event, status: :published, hidden: false, sale_starts_at: 1.day.ago, sale_ends_at: 1.day.from_now)
      expect(ticket_type.available?).to be true
    end

    it 'returns false for draft ticket types' do
      ticket_type = create(:ticket_type, event: event, status: :draft)
      expect(ticket_type.available?).to be false
    end

    it 'returns false for hidden ticket types' do
      ticket_type = create(:ticket_type, event: event, status: :published, hidden: true)
      expect(ticket_type.available?).to be false
    end

    it 'returns false for ticket types not yet on sale' do
      ticket_type = create(:ticket_type, event: event, status: :published, hidden: false, sale_starts_at: 1.day.from_now)
      expect(ticket_type.available?).to be false
    end
  end
end
