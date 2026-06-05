require 'rails_helper'

RSpec.describe TicketApplication, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:ticket) }
    it { is_expected.to belong_to(:registration_form) }
    it { is_expected.to belong_to(:reviewed_by).class_name('User').optional }
  end

  describe 'enums' do
    it do
      expect(described_class.review_statuses).to eq(
        'pending_review' => 0,
        'approved' => 1,
        'rejected' => 2
      )
    end

    it do
      expect(described_class.rsvp_statuses).to eq(
        'not_sent' => 0,
        'sent' => 1,
        'confirmed' => 2,
        'declined' => 3,
        'expired' => 4
      )
    end
  end

  describe '#assign_rsvp_token!' do
    it 'stores only a digest and returns the raw token' do
      application = create(:ticket_application)

      raw_token = application.assign_rsvp_token!

      expect(raw_token).to be_present
      expect(application.rsvp_token_digest).to be_present
      expect(application.rsvp_token_digest).not_to eq(raw_token)
      expect(application.matches_rsvp_token?(raw_token)).to eq(true)
    end
  end

  describe '#expired?' do
    it 'is false when expiry is nil' do
      application = build(:ticket_application, rsvp_expires_at: nil)

      expect(application.expired?).to eq(false)
    end

    it 'is true when expiry is in the past' do
      application = build(:ticket_application, rsvp_expires_at: 1.minute.ago)

      expect(application.expired?).to eq(true)
    end
  end
end
