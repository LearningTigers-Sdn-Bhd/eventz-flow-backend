module SeatTicketingContext
  extend ActiveSupport::Concern

  included do
    include Rails.application.routes.url_helpers
  end

  private

  def load_seat_session(param_key: :session_id, include_deleted: false)
    scope = include_deleted ? EventSeatSession.with_deleted : EventSeatSession
    @session = scope.find(params[param_key])
    
    # Skip authorization for public actions to allow anonymous access to seat selection
    public_actions = ['index', 'show', 'seats', 'lock', 'unlock', 'public_index', 'public_show', 'checkout']
    if action_name.in?(public_actions)
      skip_authorization
    else
      authorize @session
    end
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
    # Ensure event is loaded for seat status logic
    session.event if session.association(:event).loaded? == false

    session.as_json(
      include: {
        event_seat_venues: {
          include: {
            event_seat_sections: {
              include: {
                event_seat_groups: {},
                event_ticket_seats: {
                  methods: :status,
                  include: :event_seat_group_assignment
                }
              }
            }
          }
        }
      }
    ).tap do |json|
      json['event_seat_venues']&.each do |venue_json|
        venue = session.event_seat_venues.find { |v| v.id == venue_json['id'] }
        venue_json['image_url'] = venue_image_url(venue) if venue
      end
    end
  end

  def seat_session_summary(session)
    # Pre-fetch counts to avoid N+1
    section_ids = session.event_seat_venues.flat_map(&:event_seat_section_ids)
    section_counts = EventTicketSeat.where(event_seat_section_id: section_ids)
                                   .group(:event_seat_section_id).count

    session.as_json(
      include: {
        event_seat_venues: {
          include: {
            event_seat_sections: {
              include: {
                event_seat_groups: {}
              }
            }
          }
        }
      }
    ).tap do |json|
      json['event_seat_venues']&.each do |venue_json|
        venue = session.event_seat_venues.find { |v| v.id == venue_json['id'] }
        venue_json['image_url'] = venue_image_url(venue) if venue

        venue_json['event_seat_sections']&.each do |section_json|
          section_json['seats_count'] = section_counts[section_json['id']] || 0
        end
      end
    end
  end
end
