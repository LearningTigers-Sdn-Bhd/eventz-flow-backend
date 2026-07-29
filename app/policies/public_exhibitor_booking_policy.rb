class PublicExhibitorBookingPolicy < ApplicationPolicy
  def index?
    user&.active?
  end

  def show?
    owned?
  end

  def create?
    user&.active?
  end

  def update?
    owned? && record.unpaid? && record.booking_active?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user&.active?

      scope.joins(event_vendor: :vendor).where(
        event_vendors: { event_id: user.event_id, type: 'Exhibitor' }
      ).where('LOWER(users.email) = ?', user.normalized_email)
    end
  end

  private

  def owned?
    user&.active? && record.event.id == user.event_id &&
      record.event_vendor.vendor.email.to_s.downcase == user.normalized_email
  end
end
