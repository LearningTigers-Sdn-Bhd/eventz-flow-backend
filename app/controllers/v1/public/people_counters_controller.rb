# frozen_string_literal: true

module V1
  module Public
    # The big-screen page: live crowd numbers for a screen at the door. Public for
    # published events, like the check-in display, and deliberately small: who is
    # inside and how full each place is, nothing about traffic or tickets. An
    # unpublished or unknown event is a plain 404.
    class PeopleCountersController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      # GET /v1/public/events/:event_slug/people_counter
      def show
        event = Event.friendly.find(params[:event_slug])
        return head :not_found unless event.published?

        response.headers['Cache-Control'] = 'no-store'
        render json: payload(event), status: :ok
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      private

      def payload(event)
        data = PeopleCounter::EventHeadcount.new(event).call
        {
          event_title: event.title,
          configured: data[:configured],
          inside_now: data[:event][:inside_now],
          capacity: data[:event][:capacity],
          levels: data[:levels].map { |l| l.slice(:floor, :inside_now, :capacity) },
          halls: data[:halls].map { |h| h.slice(:name, :floor, :status, :inside_now, :capacity) },
          generated_at: data[:generated_at]
        }
      end
    end
  end
end
