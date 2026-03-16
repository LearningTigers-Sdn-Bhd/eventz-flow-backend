require 'rails_helper'

RSpec.describe WishModerationService do
  describe '#call' do
    it 'approves a normal wish message' do
      result = described_class.new(message: 'Blessings always').call

      expect(result.success?).to be true
      expect(result.data[:decision]).to eq('approved')
      expect(result.data[:reason]).to eq('Allowed by local filter')
    end

    it 'rejects messages with blocked language (Malay & English)' do
      blocked_words = ['pukimak', 'lancau', 'butuh kau', 'pantat', 'asshole', 'judi online', 'slot gacor',
                       'GO TO HELL', 'die now', 'kanina', 'bongok', 'bangang', 'maxwin', 'fuckk']

      blocked_words.each do |word|
        result = described_class.new(message: "Check this out: #{word}").call
        expect(result.data[:decision]).to eq('rejected')
      end
    end

    it 'rejects if guest_name contains blocked language' do
      result = described_class.new(guest_name: 'babi', message: 'Hello').call
      expect(result.data[:decision]).to eq('rejected')
    end

    it 'does not reject innocent words that only contain blocked substrings' do
      result = described_class.new(message: 'We had mamak for dinner and blessings for all').call

      expect(result.data[:decision]).to eq('approved')
    end

    it 'marks messages with domain-style spam as pending review' do
      result = described_class.new(message: 'Visit promo-site.xyz for special offers').call

      expect(result.data[:decision]).to eq('pending')
      expect(result.data[:reason]).to eq('Looks like spam or promotion')
    end

    it 'marks messages with contact-selling patterns as pending review' do
      result = described_class.new(message: 'WhatsApp me at +6012-3456789 for deposit bonus').call

      expect(result.data[:decision]).to eq('pending')
      expect(result.data[:reason]).to eq('Looks like spam or promotion')
    end

    it 'marks suspicious promotional messages as pending review' do
      result = described_class.new(message: 'Visit https://spam.test now for fast cash').call

      expect(result.success?).to be true
      expect(result.data[:decision]).to eq('pending')
      expect(result.data[:reason]).to eq('Looks like spam or promotion')
    end

    it 'marks repetitive low-quality messages as pending review' do
      result = described_class.new(message: 'hahahahahahahahahaha').call

      expect(result.success?).to be true
      expect(result.data[:decision]).to eq('pending')
      expect(result.data[:reason]).to eq('Looks repetitive or low quality')
    end
  end
end
