# Ticket groups (rooms) of an event. Anyone who can work with the event's tickets
# may look; only org owners, organizers and the event's own admin may change them
# (same rule as deleting tickets). Event team members only scan, so they stay read-only.
# `record` is a TicketGroup (or a TicketGroup.new(event: event) for collection actions).
class TicketGroupPolicy < ApplicationPolicy
  def index?
    manage? || (user.present? && user.is_event_team_member?(record.event))
  end

  def manage?
    user.present? && (user.is_org_owner? || user.is_organizer? || user.is_event_admin?(record.event))
  end

  %i[setup? update? destroy? preview? assign? move?].each do |action|
    define_method(action) { manage? }
  end
end
