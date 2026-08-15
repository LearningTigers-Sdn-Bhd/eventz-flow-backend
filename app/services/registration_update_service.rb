# frozen_string_literal: true

# Applies a self-service edit to an already-registered ticket. Re-verifies
# plate+email ownership itself (never trusts a caller to have already proven
# the match in an earlier request) via RegistrationLookupService, then
# assigns only the allowlisted editable attributes and saves.
class RegistrationUpdateService
  Result = Struct.new(:success, :ticket, :errors, keyword_init: true) do
    def success?
      success
    end
  end

  NOT_FOUND_MESSAGE = "We couldn't find a registration matching that car plate and email."
  EDITABLE_ATTRIBUTES = %w[attendee_name attendee_phone role].freeze

  def initialize(event:, plate:, email:, public_id:, attributes:, documents:)
    @event = event
    @plate = plate
    @email = email
    @public_id = public_id
    @attributes = attributes.to_h.stringify_keys
    @documents = documents.respond_to?(:to_unsafe_h) ? documents.to_unsafe_h : documents.to_h
  end

  def call
    ticket = RegistrationLookupService.new(event: @event, plate: @plate, email: @email).call
    return not_found unless ticket && ticket.public_id == @public_id

    apply_attributes!(ticket)

    result = nil
    ActiveRecord::Base.transaction do
      # Locks the vehicle for the duration of the role-conflict check + save,
      # the same guard VehicleRegistrationAssignment uses at create time, so
      # two concurrent edits can't both pass the check and both save.
      ticket.vehicle_registration.lock!

      if role_conflict?(ticket)
        result = Result.new(success: false, ticket: nil, errors: ["This vehicle already has a #{ticket.role}"])
        raise ActiveRecord::Rollback
      end

      begin
        RegistrationDocumentAttacher.new(
          event: @event, ticket: ticket, documents: @documents, replace_existing: true
        ).call
      rescue RegistrationDocumentAttacher::Error => e
        result = Result.new(success: false, ticket: nil, errors: [e.message])
        raise ActiveRecord::Rollback
      end

      if ticket.save
        result = Result.new(success: true, ticket: ticket, errors: [])
      else
        result = Result.new(success: false, ticket: nil, errors: ticket.errors.full_messages)
        raise ActiveRecord::Rollback
      end
    end
    result
  rescue ActiveRecord::RecordNotUnique
    # The model validation races under concurrent submits; the partial
    # unique index does not. Mirrors the same rescue in registrations#create.
    Result.new(success: false, ticket: nil,
               errors: ['This membership or IC/passport number is already registered for this event'])
  end

  private

  def not_found
    Result.new(success: false, ticket: nil, errors: [NOT_FOUND_MESSAGE])
  end

  def apply_attributes!(ticket)
    EDITABLE_ATTRIBUTES.each do |key|
      ticket.public_send("#{key}=", @attributes[key]) if @attributes.key?(key)
    end

    return unless @attributes.key?('custom_fields_data')

    # car_registration_number is server-derived from the vehicle's plate
    # (see VehicleRegistrationAssignment) — just as server-owned as the
    # reserved keys, so it's stripped here too rather than left editable.
    incoming = @attributes['custom_fields_data'].to_h.stringify_keys
                                                 .except(*Ticket::RESERVED_CUSTOM_FIELD_KEYS, 'car_registration_number')
    ticket.custom_fields_data = (ticket.custom_fields_data || {}).merge(incoming)
  end

  def role_conflict?(ticket)
    return false unless VehicleRegistrationAssignment::SINGLE_OCCUPANT_ROLES.include?(ticket.role)

    ticket.vehicle_registration.active_tickets
          .where.not(id: ticket.id)
          .exists?(role: ticket.role)
  end
end
