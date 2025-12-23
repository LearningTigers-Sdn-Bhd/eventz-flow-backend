# app/policies/booking_policy.rb
class BookingPolicy < ApplicationPolicy
  # record will be a hash representing a booking from the external API
  # This policy will authorize actions on a single booking record (hash)
  # after it has been potentially filtered by the service.

  def initialize(user, booking_hash, event_id)
    @user = user
    @booking = booking_hash
    @event = Event.find_by(id: event_id) # Need event object to check roles
  end

  def show?
    return false if @user.blank? || @event.blank? || @booking.blank?

    # Event admins or team members can view any booking within their event
    return true if @user.is_event_admin?(@event) || @user.is_event_team_member?(@event)

    # A business host can only view bookings where they are the assigned host
    # Assuming booking[:host_user_id] identifies the host for this booking
    return true if @user.is_business_host?(@event) && @booking["host_user_id"].to_s == @user.id.to_s

    # An attendee can view their own booking (if attendee_user_id exists)
    # return true if @booking["attendee_user_id"].to_s == @user.id.to_s

    false
  end

  def create?
    # Public booking creation, so any authenticated user can technically attempt to create one
    # Actual creation logic and available slots will be handled by service
    @user.present?
  end

  def update?
    return false if @user.blank? || @event.blank? || @booking.blank?

    # Only event admins, team members or the assigned business host can update a booking
    return true if @user.is_event_admin?(@event) || @user.is_event_team_member?(@event)
    return true if @user.is_business_host?(@event) && @booking["host_user_id"].to_s == @user.id.to_s

    false
  end

  def destroy?
    return false if @user.blank? || @event.blank? || @booking.blank?

    # Only event admins or team members can destroy a booking
    return true if @user.is_event_admin?(@event) || @user.is_event_team_member?(@event)

    false
  end

  # The Scope class is less relevant when working with non-ActiveRecord collections
  # as filtering happens in the service layer. However, if a controller attempts to
  # resolve a collection through Pundit's `policy_scope`, it would need to handle
  # an array of hashes. For this context, it's safer to avoid using policy_scope
  # for booking collections and rely on the service to return pre-filtered data.
  class Scope < Scope
    def resolve
      # Since bookings are external data (hashes), `scope` here would be an Array of hashes,
      # not an ActiveRecord relation. Pundit's `policy_scope` is designed for AR relations.
      # It's better to perform collection filtering in the service layer.
      # If this method were called, it would need to operate on `scope` as an array.
      # For now, it will return an empty array or raise an error if invoked inappropriately.
      # The controller should directly pass filtered bookings to the view/serializer.
      Rails.logger.warn "BookingPolicy::Scope#resolve called for non-ActiveRecord collection. This might be unintended."
      [] # Return an empty array to prevent unauthorized access if accidentally called
    end
  end
end
