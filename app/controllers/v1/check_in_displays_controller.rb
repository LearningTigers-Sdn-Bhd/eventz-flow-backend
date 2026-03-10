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

      handle_assets

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

    def announce
      authorize @check_in_display, :update?

      name = params[:name].to_s.strip
      return error_response(message: 'Name is required', status: :bad_request) if name.blank?

      custom_fields_data = find_attendee_custom_fields(name) || {}
      payload_custom_fields = params[:custom_fields_data]
      payload_custom_fields = payload_custom_fields.to_unsafe_h if payload_custom_fields.respond_to?(:to_unsafe_h)

      if payload_custom_fields.is_a?(Hash)
        custom_fields_data = custom_fields_data.merge(payload_custom_fields) { |_key, existing, incoming| incoming.presence || existing }
      end

      WelcomeScreenQueueService.enqueue(@event.id, name, custom_fields_data: custom_fields_data)
      success_response(data: { message: 'Guest announced', name: name })
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_check_in_display
      @check_in_display = @event.check_in_display || @event.build_check_in_display
    end

    def check_in_display_params
      params.require(:check_in_display).permit(
        :font_family, :font_size, :animation_type, :is_bold, 
        :name_color, :voice_enabled, :voice_type, :welcome_text,
        :idle_mode, :announcement_mode, :announcement_duration,
        :show_seating_plan, :seating_plan_sidebar_position, :seating_plan_duration, :active_plan_id,
        :seating_announcement_template
      )
    end

    def handle_assets
      display_params = params[:check_in_display] || {}

      # Idle Assets
      if display_params[:background_image].present? && display_params[:background_image].respond_to?(:read)
        @check_in_display.background_image.attach(display_params[:background_image])
      end
      if ActiveModel::Type::Boolean.new.cast(display_params[:remove_background_image])
        @check_in_display.background_image.purge_later if @check_in_display.background_image.attached?
      end

      if display_params[:idle_video].present? && display_params[:idle_video].respond_to?(:read)
        @check_in_display.idle_video.attach(display_params[:idle_video])
      end
      if ActiveModel::Type::Boolean.new.cast(display_params[:remove_idle_video])
        @check_in_display.idle_video.purge_later if @check_in_display.idle_video.attached?
      end

      # Announcement Assets
      if display_params[:announcement_image].present? && display_params[:announcement_image].respond_to?(:read)
        @check_in_display.announcement_image.attach(display_params[:announcement_image])
      end
      if ActiveModel::Type::Boolean.new.cast(display_params[:remove_announcement_image])
        @check_in_display.announcement_image.purge_later if @check_in_display.announcement_image.attached?
      end

      if display_params[:announcement_video].present? && display_params[:announcement_video].respond_to?(:read)
        @check_in_display.announcement_video.attach(display_params[:announcement_video])
      end
      if ActiveModel::Type::Boolean.new.cast(display_params[:remove_announcement_video])
        @check_in_display.announcement_video.purge_later if @check_in_display.announcement_video.attached?
      end
    end

    def find_attendee_custom_fields(name)
      normalized_name = name.to_s.strip.downcase
      return nil if normalized_name.blank?

      sources = @event.use_ticket ? [:ticket, :visitor] : [:visitor, :ticket]

      sources.each do |source|
        custom_fields = if source == :ticket
          @event.tickets
                .where('LOWER(attendee_name) = ?', normalized_name)
                .order(Arel.sql('check_in_at DESC NULLS LAST, updated_at DESC'))
                .limit(1)
                .pick(:custom_fields_data)
        else
          @event.visitors
                .where('LOWER(full_name) = ?', normalized_name)
                .order(Arel.sql('check_in_at DESC NULLS LAST, updated_at DESC'))
                .limit(1)
                .pick(:custom_fields_data)
        end

        return custom_fields if custom_fields.present?
      end

      nil
    end
  end
end
