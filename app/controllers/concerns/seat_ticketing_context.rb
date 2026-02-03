module SeatTicketingContext
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  private

  def load_seat_session(param_key: :session_id, include_deleted: false)
    scope = include_deleted ? EventSeatSession.with_deleted : EventSeatSession
    @session = scope.find(params[param_key])
    authorize @session
  end

  def load_seat_venue(param_key: :venue_id)
    @venue = @session.event_seat_venues.find(params[param_key])
  end

  def load_seat_section(param_key: nil)
    key = param_key || (params[:section_id] ? :section_id : :id)
    @section = @venue.event_seat_sections.find(params[key])
  end

  def load_ticket_seat(param_key: :id)
    @ticket_seat = @section.event_ticket_seats.find(params[param_key])
  end

  def venue_as_json(venue)
    venue.as_json.merge(
      image_url: venue_image_url(venue)
    )
  end

  def venue_image_url(venue)
    return nil unless venue&.image&.attached?

    url_options = (Rails.application.routes.default_url_options || {}).dup
    if respond_to?(:request) && request.present?
      url_options[:host] = request.host
      url_options[:protocol] = request.protocol.gsub('://', '')
      url_options[:port] = request.port unless [80, 443].include?(request.port)
    end

    rails_blob_url(venue.image, **url_options)
  rescue => e
    Rails.logger.error "Could not generate URL for venue #{venue&.id}: #{e.message}"
    nil
  end

  def seat_session_with_details(session)
    session.as_json(
      include: {
        event_seat_venues: {
          include: {
            event_seat_sections: {
              include: :event_ticket_seats
            }
          }
        }
      }
    ).tap do |json|
      json['event_seat_venues']&.each_with_index do |venue_json, index|
        venue = session.event_seat_venues[index]
        venue_json['image_url'] = venue_image_url(venue)
      end
    end
  end
end
