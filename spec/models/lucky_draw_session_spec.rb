require 'rails_helper'

RSpec.describe LuckyDrawSession, type: :model do
  describe 'associations' do
    it { should belong_to(:event) }
    it { should have_many(:gifts).dependent(:destroy) }
    it { should have_many(:invalid_participants).dependent(:destroy) }
  end

  describe 'validations' do
    it { should validate_presence_of(:event_id) }
    it { should validate_presence_of(:title) }
  end

  describe 'draw_styles' do
    let(:event) { create(:event) }

    context 'with valid structure' do
      it 'accepts valid draw_styles hash' do
        session = build(:lucky_draw_session, event: event, draw_styles: { style: 'wheel', theme: 'wireframe' })
        expect(session).to be_valid
      end

      it 'accepts all valid styles' do
        %w[wheel slot box].each do |style|
          session = build(:lucky_draw_session, event: event, draw_styles: { style: style, theme: 'wireframe' })
          expect(session).to be_valid
        end
      end

      it 'accepts all valid themes' do
        %w[wireframe colorful cartoon].each do |theme|
          session = build(:lucky_draw_session, event: event, draw_styles: { style: 'wheel', theme: theme })
          expect(session).to be_valid
        end
      end
    end

    context 'with invalid structure' do
      it 'rejects non-hash values' do
        session = build(:lucky_draw_session, event: event, draw_styles: 'invalid')
        expect(session).not_to be_valid
        expect(session.errors[:draw_styles]).to include('must be a hash')
      end

      it 'rejects invalid style values' do
        session = build(:lucky_draw_session, event: event, draw_styles: { style: 'invalid', theme: 'wireframe' })
        expect(session).not_to be_valid
        expect(session.errors[:draw_styles]).to be_present
      end

      it 'rejects invalid theme values' do
        session = build(:lucky_draw_session, event: event, draw_styles: { style: 'wheel', theme: 'invalid' })
        expect(session).not_to be_valid
        expect(session.errors[:draw_styles]).to be_present
      end

      it 'rejects missing style' do
        session = build(:lucky_draw_session, event: event, draw_styles: { theme: 'wireframe' })
        expect(session).not_to be_valid
        expect(session.errors[:draw_styles]).to be_present
      end
    end

    context 'with empty or nil draw_styles' do
      it 'allows empty hash' do
        session = build(:lucky_draw_session, event: event, draw_styles: {})
        expect(session).to be_valid
      end

      it 'allows nil draw_styles' do
        session = build(:lucky_draw_session, event: event, draw_styles: nil)
        expect(session).to be_valid
      end
    end
  end

  describe 'helper methods' do
    let(:event) { create(:event) }
    let(:session) { create(:lucky_draw_session, event: event, draw_styles: { style: 'slot', theme: 'colorful' }) }

    describe '#draw_style' do
      it 'returns the style from draw_styles' do
        expect(session.draw_style).to eq('slot')
      end

      it 'returns nil when draw_styles is empty' do
        session.draw_styles = {}
        expect(session.draw_style).to be_nil
      end
    end

    describe '#draw_theme' do
      it 'returns the theme from draw_styles' do
        expect(session.draw_theme).to eq('colorful')
      end

      it 'returns wireframe as default when theme is missing' do
        session.draw_styles = { style: 'wheel' }
        expect(session.draw_theme).to eq('wireframe')
      end

      it 'returns wireframe as default when draw_styles is empty' do
        session.draw_styles = {}
        expect(session.draw_theme).to eq('wireframe')
      end
    end
  end

  describe 'scopes' do
    let(:event) { create(:event) }
    let!(:session1) { create(:lucky_draw_session, event: event, draw_date: Date.today + 1.day, created_at: 2.days.ago) }
    let!(:session2) { create(:lucky_draw_session, event: event, draw_date: Date.today, created_at: 1.day.ago) }
    let!(:session3) { create(:lucky_draw_session, event: event, draw_date: nil, created_at: 3.days.ago) }

    it 'orders by draw_date and created_at' do
      ordered = LuckyDrawSession.ordered
      # PostgreSQL orders NULL values last by default
      expect(ordered.first).to eq(session2) # today (earliest date)
      expect(ordered.second).to eq(session1) # tomorrow
      expect(ordered.third).to eq(session3) # nil dates last
    end
  end
end
