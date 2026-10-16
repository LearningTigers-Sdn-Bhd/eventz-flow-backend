require 'rails_helper'

RSpec.describe EventEmailSetting, type: :model do
  let(:event) { create(:event) }

  def setting(address) = described_class.new(event:, sender_address: address)

  it 'accepts the notify domain and normalizes case' do
    s = setting(' Events@Notify.EventzFlow.com ')
    expect(s).to be_valid
    expect(s.sender_address).to eq('events@notify.eventzflow.com')
  end

  it 'accepts blank' do
    expect(setting('')).to be_valid
  end

  it 'rejects other domains' do
    s = setting('events@gmail.com')
    expect(s).not_to be_valid
    expect(s.errors[:sender_address]).to be_present
  end
end
