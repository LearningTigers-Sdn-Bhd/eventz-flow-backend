# app/policies/vendor_policy.rb
class VendorPolicy < UserPolicy
  # Note: user = @current_user, record = the User instance with vendor role
  #
  # Team rule: organizers assigned to the same event share access to that event's
  # vendors, regardless of who created the vendor account. Organizers with no
  # shared event still cannot see each other's vendors.

  class Scope < UserPolicy::Scope
    def resolve
      return scope.all if user.org_owner?
      return scope.where(id: user.id) unless user.organizer?

      scope.where(created_by_id: coorganizer_ids).or(scope.where(id: teammate_vendor_ids))
    end

    private

    # ponytail: event_assignments is the only user<->event link (events has no owner column).
    # Anyone staffing the same event as the creator counts as "my org team" for
    # that vendor, even before it's formally assigned via EventVendor.
    def coorganizer_ids
      EventAssignment.where(event_id: user.event_assignments.select(:event_id)).select(:user_id)
    end

    def teammate_vendor_ids
      EventVendor.where(event_id: user.event_assignments.select(:event_id)).select(:vendor_id)
    end
  end

  def index?
    # Only organizers and org_owners can list vendors
    user.organizer? || user.org_owner?
  end

  def show?
    # Organizers and org_owners can view vendor details
    # Vendors can view their own details
    user.org_owner? || user.organizer? || record == user
  end

  def create?
    # Only organizers and org_owners can create vendor accounts
    user.organizer? || user.org_owner?
  end

  def update?
    # Org owners can update any vendor
    # Organizers can update vendors created by a co-organizer on a shared event,
    # or vendors already assigned to a shared event
    user.org_owner? ||
      (user.organizer? && (coorganizer_vendor? || teammate_vendor?))
  end

  def toggle_status?
    # Same rules as update
    update?
  end

  def destroy?
    return true if user.org_owner?
    return false unless user.organizer?
    return true if record.created_by_id == user.id

    # Destroy removes the vendor's account everywhere, not just from one event.
    # Unlike update, a coorganizer link alone isn't enough here - only allow it
    # when every event the vendor belongs to is one this user staffs.
    teammate_vendor? && !vendor_in_outside_event?
  end

  private

  def my_event_ids
    user.event_assignments.select(:event_id)
  end

  # True when the vendor's creator staffs at least one event I also staff -
  # mirrors Scope#coorganizer_ids so index/show/update/destroy agree.
  def coorganizer_vendor?
    EventAssignment.where(user_id: record.created_by_id, event_id: my_event_ids).exists?
  end

  def teammate_vendor?
    EventVendor.where(vendor_id: record.id, event_id: my_event_ids).exists?
  end

  def vendor_in_outside_event?
    EventVendor.where(vendor_id: record.id).where.not(event_id: my_event_ids).exists?
  end
end
