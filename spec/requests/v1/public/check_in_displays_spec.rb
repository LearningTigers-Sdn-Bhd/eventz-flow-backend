# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::Public::CheckInDisplays', type: :request do
  let(:event) { create(:event) }

  describe 'GET /v1/public/events/:event_slug/check_in_display' do
    let(:endpoint) { "/v1/public/events/#{event.slug}/check_in_display" }

    context 'when no check_in_display exists' do
      it 'returns default settings without authentication' do
        get endpoint

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['font_family']).to eq('Inter')
        expect(data['font_size']).to eq(72)
        expect(data['animation_type']).to eq('fade_in')
        expect(data['background_image_url']).to be_nil
      end

      it 'includes event information' do
        get endpoint

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['event']).to be_present
        expect(data['event']['id']).to eq(event.id)
        expect(data['event']['title']).to eq(event.title)
        expect(data['event']['slug']).to eq(event.slug)
      end
    end

    context 'when check_in_display exists' do
      let!(:display) do
        create(:check_in_display,
               event: event,
               font_family: 'Roboto',
               font_size: 96,
               animation_type: :zoom_in)
      end

      it 'returns saved settings' do
        get endpoint

        expect(response).to have_http_status(:ok)
        data = json_response['data']
        expect(data['id']).to eq(display.id)
        expect(data['font_family']).to eq('Roboto')
        expect(data['font_size']).to eq(96)
        expect(data['animation_type']).to eq('zoom_in')
      end

      it 'includes event information with saved display' do
        get endpoint

        data = json_response['data']
        expect(data['event']['id']).to eq(event.id)
        expect(data['event']['title']).to eq(event.title)
      end
    end

    context 'with invalid event slug' do
      it 'returns 404 for non-existent event' do
        get '/v1/public/events/non-existent-event/check_in_display'

        expect(response).to have_http_status(:not_found)
        expect(json_response['message']).to eq('Resource not found')
      end
    end

    context 'animation types' do
      it 'returns fade_in animation type' do
        create(:check_in_display, event: event, animation_type: :fade_in)
        get endpoint
        expect(json_response['data']['animation_type']).to eq('fade_in')
      end

      it 'returns slide_up animation type' do
        create(:check_in_display, event: event, animation_type: :slide_up)
        get endpoint
        expect(json_response['data']['animation_type']).to eq('slide_up')
      end

      it 'returns bounce animation type' do
        create(:check_in_display, event: event, animation_type: :bounce)
        get endpoint
        expect(json_response['data']['animation_type']).to eq('bounce')
      end

      it 'returns typewriter animation type' do
        create(:check_in_display, event: event, animation_type: :typewriter)
        get endpoint
        expect(json_response['data']['animation_type']).to eq('typewriter')
      end

      it 'returns no_animation animation type' do
        create(:check_in_display, event: event, animation_type: :no_animation)
        get endpoint
        expect(json_response['data']['animation_type']).to eq('no_animation')
      end
    end
  end

  def json_response
    JSON.parse(response.body)
  end
end
