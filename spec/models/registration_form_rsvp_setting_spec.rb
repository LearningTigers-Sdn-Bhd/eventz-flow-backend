require 'rails_helper'

RSpec.describe RegistrationFormRsvpSetting, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:registration_form) }
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:review_sla_hours).is_greater_than(0) }
    it { is_expected.to validate_numericality_of(:rsvp_expires_in_hours).is_greater_than(0).allow_nil }
  end

  it 'defaults workflow off and review SLA to 48 hours' do
    setting = described_class.new

    expect(setting.enabled).to eq(false)
    expect(setting.rsvp_required).to eq(false)
    expect(setting.review_sla_hours).to eq(48)
    expect(setting.rsvp_expires_in_hours).to be_nil
  end
end
