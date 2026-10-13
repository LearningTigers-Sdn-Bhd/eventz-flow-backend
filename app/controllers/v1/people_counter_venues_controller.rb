module V1
  # Venues on the event's people-counter service, for the hall "link counter" dropdown.
  # Org owners only (see EventHallPolicy#link_counter?).
  class PeopleCounterVenuesController < ApplicationController
    before_action :authenticate_user!

    # GET /v1/events/:event_id/people_counter/venues
    def index
      event = Event.with_deleted.find(params[:event_id])
      authorize EventHall.new(event: event), :link_counter?

      venues = PeopleCounter::Client.for_event(event).venues
      render json: venues.map { |v| v.slice("id", "name", "capacity") }, status: :ok
    rescue PeopleCounter::Client::Error => e
      # Never 401/403 here: the panel treats those as "session expired" and logs out.
      Rails.logger.warn("People counter venues unavailable: #{e.message}")
      render json: { errors: ["People counter is unavailable"] }, status: :service_unavailable
    end
  end
end
