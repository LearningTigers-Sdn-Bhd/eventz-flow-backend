# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInDisplay, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:event) }
  end

  describe 'enums' do
    it do
      is_expected.to define_enum_for(:animation_type)
        .with_values(fade_in: 0, slide_up: 1, zoom_in: 2, bounce: 3, typewriter: 4, no_animation: 5)
        .with_default(:fade_in)
        .with_prefix
    end
  end

  describe 'validations' do
    it { is_expected.to validate_numericality_of(:font_size).is_greater_than(0) }

    describe 'font_size' do
      let(:event) { create(:event) }

      it 'is invalid with zero' do
        display = build(:check_in_display, event: event, font_size: 0)
        expect(display).not_to be_valid
        expect(display.errors[:font_size]).to include('must be greater than 0')
      end

      it 'is invalid with negative value' do
        display = build(:check_in_display, event: event, font_size: -10)
        expect(display).not_to be_valid
      end

      it 'is valid with positive value' do
        display = build(:check_in_display, event: event, font_size: 48)
        expect(display).to be_valid
      end
    end
  end

  describe 'defaults' do
    let(:event) { create(:event) }
    let(:display) { event.build_check_in_display }

    it 'has default font_family of Inter' do
      expect(display.font_family).to eq('Inter')
    end

    it 'has default font_size of 72' do
      expect(display.font_size).to eq(72)
    end

    it 'has default animation_type of fade_in' do
      expect(display.animation_type).to eq('fade_in')
    end
  end

  describe '#as_json_for_api' do
    let(:event) { create(:event) }
    let(:display) { create(:check_in_display, event: event) }

    it 'returns expected attributes' do
      json = display.as_json_for_api

      expect(json[:id]).to eq(display.id)
      expect(json[:event_id]).to eq(event.id)
      expect(json[:font_family]).to eq('Inter')
      expect(json[:font_size]).to eq(72)
      expect(json[:animation_type]).to eq('fade_in')
      expect(json[:background_image_url]).to be_nil
      expect(json[:created_at]).to be_present
      expect(json[:updated_at]).to be_present
    end

    context 'with include_event: true' do
      it 'includes event data instead of timestamps' do
        json = display.as_json_for_api(include_event: true)

        expect(json[:event]).to be_present
        expect(json[:event][:id]).to eq(event.id)
        expect(json[:event][:title]).to eq(event.title)
        expect(json[:event][:slug]).to eq(event.slug)
        expect(json).not_to have_key(:created_at)
        expect(json).not_to have_key(:updated_at)
      end
    end

    context 'for unsaved record' do
      let(:unsaved_display) { event.build_check_in_display }

      it 'returns nil for id and timestamps' do
        json = unsaved_display.as_json_for_api

        expect(json[:id]).to be_nil
        expect(json[:event_id]).to eq(event.id)
        expect(json[:font_family]).to eq('Inter')
      end
    end
  end

  describe 'event association uniqueness' do
    let(:event) { create(:event) }

    it 'allows only one check_in_display per event' do
      create(:check_in_display, event: event)

      duplicate = build(:check_in_display, event: event)
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end
  end
end
