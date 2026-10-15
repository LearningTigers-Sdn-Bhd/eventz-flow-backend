# frozen_string_literal: true

class EventIdResolver
  def self.resolve(params)
    direct = params[:event_id] || params[:business_matching_event_id] || params.dig(:voucher, :event_id)
    return direct.to_i if direct.present? && direct.to_s.match?(/\A\d+\z/)

    if params[:controller] == 'v1/events' && params[:id].to_s.match?(/\A\d+\z/)
      return params[:id].to_i
    end

    slug = params[:event_slug] || params[:slug]
    if slug.present?
      event = Event.with_deleted.friendly.find_by(slug: slug) ||
              (slug.to_s.match?(/\A\d+\z/) ? Event.with_deleted.find_by(id: slug) : nil)
      return event&.id
    end

    if params[:public_id].present?
      return Ticket.find_by(public_id: params[:public_id])&.event_id ||
             Visitor.find_by(public_id: params[:public_id])&.event_id
    end

    nil
  end
end
