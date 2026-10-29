module V1
  # Counted areas of an event (halls / levels) and their link to the people-counter service.
  class EventHallsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_hall, only: %i[show update destroy]

    # GET /v1/events/:event_id/event_halls
    def index
      authorize @event.event_halls.build, :index?
      halls = policy_scope(@event.event_halls).ordered
      render json: halls.map { |hall| format_hall(hall) }, status: :ok
    end

    # GET /v1/events/:event_id/event_halls/headcount
    # Live + event-wide people counts rolled up by hall, level and event.
    def headcount
      authorize EventHall.new(event: @event), :index?
      render json: PeopleCounter::EventHeadcount.new(@event).call, status: :ok
    end

    # GET /v1/events/:event_id/event_halls/analytics?date=YYYY-MM-DD&bucket=15|60
    # One day of counts over time, per hall, level and event, with peak stats.
    def analytics
      authorize EventHall.new(event: @event), :index?
      render json: analytics_service.call, status: :ok
    end

    # GET /v1/events/:event_id/event_halls/daily
    # Every event day up to today: arrivals, departures and peak, event-wide and per hall.
    def daily
      authorize EventHall.new(event: @event), :index?
      render json: PeopleCounter::EventDays.new(@event).call, status: :ok
    end

    # GET /v1/events/:event_id/event_halls/analytics_export?date=YYYY-MM-DD&bucket=15|60&hour12=1&all_days=1
    # The same day as a formatted Excel report for organizers; all_days=1 gives the whole event instead.
    def analytics_export
      authorize EventHall.new(event: @event), :index?
      report = PeopleCounter::ReportWorkbook.new(@event, date: params[:date], bucket: params[:bucket].to_i,
                                                 hour12: params[:hour12] == '1', all_days: params[:all_days] == '1')
      send_data report.call, filename: report.filename,
                             type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    end

    # GET /v1/events/:event_id/event_halls/:id
    def show
      authorize @event_hall
      render json: format_hall(@event_hall), status: :ok
    end

    # POST /v1/events/:event_id/event_halls
    def create
      hall = @event.event_halls.build(event_hall_params)
      authorize hall
      authorize_counter_link(hall)

      if hall.save
        render json: format_hall(hall), status: :created
      else
        render json: { errors: hall.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:event_id/event_halls/:id
    def update
      authorize @event_hall
      authorize_counter_link(@event_hall)

      if @event_hall.update(event_hall_params)
        render json: format_hall(@event_hall), status: :ok
      else
        render json: { errors: @event_hall.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/event_halls/:id
    def destroy
      authorize @event_hall
      @event_hall.destroy
      head :no_content
    end

    private

    def set_event
      # Archived events stay reachable for record-keeping
      @event = Event.with_deleted.find(params[:event_id])
    end

    def analytics_service
      PeopleCounter::EventAnalytics.new(@event, date: params[:date], bucket: params[:bucket].to_i)
    end

    def set_event_hall
      @event_hall = @event.event_halls.find(params[:id])
    end

    # Only org owners may send counter_venue_id (even to clear it); others get 403.
    def authorize_counter_link(hall)
      authorize hall, :link_counter? if params[:event_hall].key?(:counter_venue_id)
    end

    def event_hall_params
      params.require(:event_hall).permit(:name, :floor, :counter_venue_id, :position)
    end

    def format_hall(hall)
      {
        id: hall.id,
        event_id: hall.event_id,
        name: hall.name,
        floor: hall.floor,
        counter_venue_id: hall.counter_venue_id,
        position: hall.position,
        created_at: hall.created_at,
        updated_at: hall.updated_at
      }
    end
  end
end
