# frozen_string_literal: true

module V1
  class CheckInDisplaysController < ApplicationController
    before_action :set_event
    before_action :set_check_in_display

    def show
      authorize @check_in_display
      success_response(data: @check_in_display.as_json_for_api)
    end

    def update
      authorize @check_in_display

      handle_background_image

      if @check_in_display.update(check_in_display_params)
        success_response(data: @check_in_display.as_json_for_api)
      else
        error_response(
          message: 'Validation failed',
          errors: @check_in_display.errors.full_messages,
          status: :unprocessable_content
        )
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_check_in_display
      @check_in_display = @event.check_in_display || @event.build_check_in_display
    end

    def check_in_display_params
      params.require(:check_in_display).permit(:font_family, :font_size, :animation_type, :is_bold, :name_color, :voice_enabled, :voice_type, :welcome_text)
    end

    def handle_background_image
      display_params = params[:check_in_display] || {}

      if display_params[:background_image].present? && display_params[:background_image].respond_to?(:read)
        @check_in_display.background_image.attach(display_params[:background_image])
        return
      end

      if ActiveModel::Type::Boolean.new.cast(display_params[:remove_background_image])
        @check_in_display.background_image.purge_later if @check_in_display.background_image.attached?
      end
    end
  end
end
