require 'rails_helper'

RSpec.describe 'V1::Public::Events', type: :request do
  describe 'GET /v1/public/events/:slug' do
    it 'returns default wishes wall settings when no row exists' do
      event = create(:event, status: :published)

      get "/v1/public/events/#{event.slug}", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'wish_wall_setting', 'display_mode')).to eq('cards')
      expect(json.dig('data', 'wish_wall_setting', 'animation_shape')).to be_nil
      expect(json.dig('data', 'wish_wall_setting', 'animation_text')).to be_nil
      expect(json.dig('data', 'wish_wall_setting', 'accent_color')).to be_nil
      expect(json.dig('data', 'wish_wall_setting', 'header_text_color')).to be_nil
      expect(json.dig('data', 'wish_wall_setting', 'card_background_color')).to be_nil
      expect(json.dig('data', 'wish_wall_setting', 'background_image_url')).to be_nil
    end

    it 'returns saved wishes wall settings on the public event payload' do
      event = create(:event, status: :published)
      setting = create(
        :wish_wall_setting,
        event: event,
        display_mode: 'animation',
        animation_shape: 'names',
        animation_text: 'Aisyah & Faiz',
        accent_color: '#F59E0B',
        header_text_color: '#111827',
        card_background_color: '#FFFBEB'
      )
      setting.background_image.attach(
        fixture_file_upload(Rails.root.join('spec/fixtures/files/test_image.png'), 'image/png')
      )

      get "/v1/public/events/#{event.slug}", as: :json

      expect(response).to have_http_status(:ok)
      expect(json.dig('data', 'wish_wall_setting', 'display_mode')).to eq('animation')
      expect(json.dig('data', 'wish_wall_setting', 'animation_shape')).to eq('names')
      expect(json.dig('data', 'wish_wall_setting', 'animation_text')).to eq('Aisyah & Faiz')
      expect(json.dig('data', 'wish_wall_setting', 'accent_color')).to eq('#F59E0B')
      expect(json.dig('data', 'wish_wall_setting', 'header_text_color')).to eq('#111827')
      expect(json.dig('data', 'wish_wall_setting', 'card_background_color')).to eq('#FFFBEB')
      expect(json.dig('data', 'wish_wall_setting', 'background_image_url')).to include('/rails/active_storage/blobs/')
    end
  end

  describe 'GET /v1/public/events/:slug/business_matching_booking_status' do
    it 'is open by default (enabled, no cutoff date)' do
      event = create(:event, status: :published)

      get "/v1/public/events/#{event.slug}/business_matching_booking_status", as: :json

      expect(response).to have_http_status(:ok)
      expect(json['enabled']).to eq(true)
      expect(json['cutoff_date']).to be_nil
      expect(json['is_open']).to eq(true)
    end

    it 'is closed once disabled' do
      event = create(:event, status: :published, business_matching_public_booking_enabled: false)

      get "/v1/public/events/#{event.slug}/business_matching_booking_status", as: :json

      expect(json['is_open']).to eq(false)
    end

    it 'is closed once the cutoff date has passed, even if still enabled' do
      event = create(:event, status: :published, business_matching_public_booking_cutoff_date: Date.current - 1)

      get "/v1/public/events/#{event.slug}/business_matching_booking_status", as: :json

      expect(json['enabled']).to eq(true)
      expect(json['is_open']).to eq(false)
    end
  end
end
