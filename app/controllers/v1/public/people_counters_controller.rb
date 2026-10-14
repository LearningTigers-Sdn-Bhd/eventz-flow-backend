# frozen_string_literal: true

module V1
  module Public
    # The big-screen page: live crowd numbers for a screen at the door. Public for
    # published events with the People Counter turned on, like the check-in
    # display, and deliberately small: who is inside and how full each place is,
    # nothing about traffic or tickets. Anything else is a plain 404.
    #
    # `?level=Level 2` narrows the page to one level: its total and its halls only,
    # for a screen at that level's entrance. `?hall=Main Hall` narrows it to one
    # hall (add `level` when two levels share a hall name), for a screen at that
    # hall's door. Names match ignoring case and extra spaces, so a retyped link
    # still works. A level or hall that doesn't exist is a 404.
    class PeopleCountersController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      # GET /v1/public/events/:event_slug/people_counter[?level=...]
      def show
        event = Event.friendly.find(params[:event_slug])
        return head :not_found unless event.published? && event.use_people_counter?

        body = payload(event, params[:level].presence, params[:hall].presence)
        return head :not_found unless body

        response.headers['Cache-Control'] = 'no-store'
        render json: body, status: :ok
      rescue ActiveRecord::RecordNotFound
        head :not_found
      end

      private

      # The whole event, one level of it, or one hall. Nil when the asked-for level or hall isn't there.
      def payload(event, level, hall_name)
        data = PeopleCounter::EventHeadcount.new(event).call
        total = data[:event]
        levels = data[:levels]
        halls = data[:halls]
        hall = nil

        if level
          total = levels.find { |l| l[:floor] && same_name?(l[:floor], level) }
          return nil unless total

          level = total[:floor]
          levels = [total]
          halls = halls.select { |h| h[:floor] == level }
        end

        if hall_name
          hall = halls.find { |h| same_name?(h[:name], hall_name) }
          return nil unless hall

          total = hall.merge(halls: 1, halls_counted: hall[:status] == 'ok' ? 1 : 0)
          levels = []
          halls = [hall]
        end

        {
          event_title: event.title,
          level: level,
          hall: hall&.dig(:name),
          configured: data[:configured],
          inside_now: total[:inside_now],
          capacity: total[:capacity],
          halls_counted: total[:halls_counted],
          halls_total: total[:halls],
          levels: levels.map { |l| l.slice(:floor, :inside_now, :capacity) },
          halls: halls.map { |h| h.slice(:name, :floor, :status, :inside_now, :capacity) },
          generated_at: data[:generated_at]
        }
      end

      def same_name?(name, asked)
        name.to_s.squish.casecmp?(asked.to_s.squish)
      end
    end
  end
end
