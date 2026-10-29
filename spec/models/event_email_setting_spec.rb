require 'rails_helper'

RSpec.describe EventEmailSetting, type: :model do
  let(:event) { create(:event) }

  def setting(address) = described_class.new(event:, sender_address: address)

  it 'accepts the sender domain and normalizes case' do
    s = setting(' Events@Updates.EventzFlow.com ')
    expect(s).to be_valid
    expect(s.sender_address).to eq('events@updates.eventzflow.com')
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
