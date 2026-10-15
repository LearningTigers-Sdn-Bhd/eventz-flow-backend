module V1
  # An event's link to the people-counter service: its URL and an API key created
  # there. Org owners only. The key is write-only: responses carry just its prefix.
  class PeopleCounterConnectionsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event

    # GET /v1/events/:event_id/people_counter_connection
    def show
      authorize record
      render json: format_connection, status: :ok
    end

    # PUT /v1/events/:event_id/people_counter_connection
    def update
      connection = record
      authorize connection

      attrs = connection_params
      return render_url_change_needs_key if keeps_key_for_new_url?(connection, attrs)

      attrs = attrs.except(:api_key) if connection.persisted? && attrs[:api_key].blank?
      if connection.update(attrs)
        render json: format_connection, status: :ok
      else
        render json: { errors: connection.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/people_counter_connection
    def destroy
      authorize record
      record.destroy if record.persisted?
      head :no_content
    end

    # POST /v1/events/:event_id/people_counter_connection/test
    # Tries a URL + key (or the saved ones) and reports the result. Always 200:
    # a failed test is an answer, not a failed request.
    def test
      authorize record, :test?
      attrs = connection_params
      return render_url_change_needs_key if keeps_key_for_new_url?(record, attrs)

      client = PeopleCounter::Client.new(
        base_url: attrs[:base_url].presence || record.base_url,
        token: attrs[:api_key].presence || record.api_key,
        guard: PeopleCounter::Client.guard?
      )
      render json: { ok: true, venues: client.venues.size }, status: :ok
    rescue PeopleCounter::Client::Unauthorized
      render json: { ok: false, reason: "unauthorized", message: "The counter service rejected this key. It may be wrong, expired or revoked." }
    rescue PeopleCounter::Client::Error => e
      render json: { ok: false, reason: "unreachable", message: e.message }
    end

    private

    def set_event
      # Archived events stay reachable for record-keeping
      @event = Event.with_deleted.find(params[:event_id])
    end

    # The saved connection, or an unsaved one so Pundit has a record (and an event) to check.
    # Not built through the event: that would make the event look configured.
    def record
      @record ||= @event.people_counter_connection || PeopleCounterConnection.new(event: @event)
    end

    def connection_params
      params.fetch(:people_counter_connection, {}).permit(:base_url, :api_key)
    end

    # A blank key means "keep the saved one". That must never ship the saved key to
    # a different address, so changing the URL requires typing the key again.
    def keeps_key_for_new_url?(connection, attrs)
      return false unless connection.persisted? && attrs[:api_key].blank? && attrs[:base_url].present?

      attrs[:base_url].to_s.strip.chomp("/") != connection.base_url
    end

    def render_url_change_needs_key
      render json: { errors: ["Enter the API key again when you change the URL."] }, status: :unprocessable_content
    end

    def format_connection
      connection = record if record.persisted?
      return { configured: true, source: "event", base_url: connection.base_url, key_prefix: connection.key_prefix } if connection

      if PeopleCounter::Client.configured_for?(@event)
        { configured: true, source: "environment", base_url: ENV["PEOPLE_COUNTER_URL"], key_prefix: nil }
      else
        { configured: false, source: nil, base_url: nil, key_prefix: nil }
      end
    end
  end
end
