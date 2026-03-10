require 'rails_helper'

RSpec.describe Wish, type: :model do
  it { is_expected.to belong_to(:event) }
  it { is_expected.to belong_to(:visitor).optional }
  it { is_expected.to validate_presence_of(:guest_name) }
  it { is_expected.to validate_length_of(:guest_name).is_at_most(100) }
  it { is_expected.to validate_presence_of(:message) }
  it { is_expected.to validate_length_of(:message).is_at_most(300) }
  it { is_expected.to define_enum_for(:status).with_values(pending: 0, approved: 1, rejected: 2) }

  describe '.for_display' do
    it 'returns approved wishes newest-first and limits to 6' do
      event = create(:event)
      older = create(:wish, :approved, event: event, approved_at: 2.minutes.ago)
      newer = create(:wish, :approved, event: event, approved_at: 1.minute.ago)
      create(:wish, event: event)
      create(:wish, :rejected, event: event)

      expect(event.wishes.for_display).to eq([newer, older])
    end
  end
end
