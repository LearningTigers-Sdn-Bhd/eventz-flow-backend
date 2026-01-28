# frozen_string_literal: true

module V1
  module Public
    class CheckInDisplaysController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      before_action :set_event

      def show
        @check_in_display = @event.check_in_display || @event.build_check_in_display
        success_response(data: @check_in_display.as_json_for_api(include_event: true))
      end

      private

      def set_event
        @event = Event.friendly.find(params[:event_slug])
      end
    end
  end
end
