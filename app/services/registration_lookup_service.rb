# frozen_string_literal: true

# Finds the one active ticket for an event whose vehicle plate and attendee
# email both match, case-insensitively. Used by the public registration-edit
# feature to prove ownership without requiring an account/login.
#
# Returns nil (never raises) on any kind of mismatch — the caller renders a
# single generic "not found" message so a mismatch never reveals which half
# (plate vs. email) was wrong.
class RegistrationLookupService
  def initialize(event:, plate:, email:)
    @event = event
    @plate = VehicleRegistration.normalize_plate(plate)
    @email = email.to_s.strip.downcase
  end

  def call
    return nil if @plate.blank? || @email.blank?

    vehicle = VehicleRegistration.find_by(event: @event, normalized_plate: @plate)
    return nil unless vehicle

    # attendee_email_norm is the same normalized column the rest of the app
    # matches attendee email against (see Ticket#normalize_email_key) —
    # querying it keeps this in sync with that rule instead of re-deriving
    # the normalization here, and lets Postgres do the matching instead of
    # loading every active ticket on the vehicle into Ruby.
    # .order(:id) makes the match deterministic (oldest ticket wins) on the
    # rare chance two occupants of the same vehicle share an email.
    vehicle.active_tickets
           .includes(:ticket_type, vehicle_registration: :registration_form)
           .where(attendee_email_norm: @email)
           .order(:id)
           .first
  end
end
