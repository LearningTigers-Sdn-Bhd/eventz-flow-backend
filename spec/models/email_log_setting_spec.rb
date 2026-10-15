require 'rails_helper'

RSpec.describe EmailLogSetting do
  describe '.current' do
    it 'creates the singleton with defaults once' do
      expect { described_class.current }.to change(described_class, :count).by(1)
      expect(described_class.current).to have_attributes(retention_days: 730, protected_retention_days: 1825)
      expect(described_class.count).to eq(1)
    end
  end

  describe 'validations' do
    it 'rejects windows shorter than 30 days or longer than 10 years' do
      expect(described_class.new(retention_days: 29, protected_retention_days: 730)).not_to be_valid
      expect(described_class.new(retention_days: 365, protected_retention_days: 3651)).not_to be_valid
    end

    it 'rejects a protected window shorter than the routine one' do
      setting = described_class.new(retention_days: 365, protected_retention_days: 200)

      expect(setting).not_to be_valid
      expect(setting.errors[:protected_retention_days]).to be_present
    end
  end

  describe '#purgeable' do
    let(:setting) { described_class.new(retention_days: 100, protected_retention_days: 300) }

    it 'keeps proof-of-problem rows longer than routine rows' do
      old_routine = create(:email_delivery, :delivered, created_at: 101.days.ago)
      old_bounced = create(:email_delivery, status: 'bounced', created_at: 200.days.ago)
      ancient_bounced = create(:email_delivery, status: 'bounced', created_at: 301.days.ago)
      recent = create(:email_delivery, :delivered, created_at: 10.days.ago)

      ids = setting.purgeable.pluck(:id)

      expect(ids).to contain_exactly(old_routine.id, ancient_bounced.id)
      expect(ids).not_to include(old_bounced.id, recent.id)
    end
  end
end
