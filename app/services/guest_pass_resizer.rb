# frozen_string_literal: true

# Grows or shrinks an existing guest pass pack (one registration batch created
# by TicketsController#create_guest_passes) without recreating its tickets, so
# the QR codes already handed out stay valid.
#
# Growing adds tickets to the same batch. Shrinking archives the highest-numbered
# passes that are still untouched placeholders (not checked in, not renamed).
# Placeholder names ("<label> Pax i/N") are rewritten to the new total.
class GuestPassResizer
  PLACEHOLDER_NAME = %r{\A.+ Pax \d+/\d+\z}

  Result = Struct.new(:status, :quantity, :added, :removed, :errors, keyword_init: true) do
    def success? = status == :ok
  end

  def self.call(...) = new(...).call

  # @param can_remove [Boolean] shrinking archives tickets, which is stricter than adding
  def initialize(event, batch_id:, quantity:, can_remove:)
    @event = event
    @batch_id = batch_id
    @quantity = quantity
    @can_remove = can_remove
  end

  def call
    return failure(:unprocessable_content, 'Quantity must be between 1 and 500') unless @quantity.between?(1, 500)

    passes = @event.tickets.where(registration_batch_id: @batch_id).where.not(guest_pass_label: nil).order(:id).to_a
    return failure(:not_found, 'Guest pass batch not found') if passes.empty?

    current = passes.size
    return failure(:forbidden, 'Not authorized to remove passes') if @quantity < current && !@can_remove

    added = []
    removed = []
    problem = nil

    ActiveRecord::Base.transaction do
      if @quantity > current
        problem = capacity_error(passes.first, @quantity - current)
        added = add_passes(passes.first, current) unless problem
      elsif @quantity < current
        removed = removable_passes(passes, current - @quantity)
        problem = removal_error(removed.size, current - @quantity) if removed.size < current - @quantity
        removed.each { |ticket| raise ActiveRecord::Rollback unless ticket.archive } unless problem
      end

      renumber(passes - removed) unless problem
    end

    return failure(:unprocessable_content, problem) if problem

    Result.new(status: :ok, quantity: @quantity, added: added, removed: removed, errors: [])
  end

  private

  def failure(status, message)
    Result.new(status: status, errors: [message])
  end

  # Placeholder passes hold real quota, same as any paid ticket.
  def capacity_error(template, needed)
    ticket_type = template.ticket_type
    return unless ticket_type.quantity.present? && ticket_type.remaining_quantity.to_i < needed

    "Not enough capacity: #{ticket_type.remaining_quantity} seat(s) left for #{ticket_type.name}"
  end

  def add_passes(template, current)
    (current + 1..@quantity).map do |i|
      ticket = @event.tickets.build(
        attendee_name: "#{template.guest_pass_label} Pax #{i}/#{@quantity}",
        guest_pass_label: template.guest_pass_label,
        attendee_email: template.attendee_email,
        attendee_phone: template.attendee_phone,
        role: template.role,
        ticket_type: template.ticket_type,
        registration_batch_id: @batch_id,
        status: :purchased,
        payment_status: :paid
      )
      ticket.suppress_confirmation_email = true
      ticket.save!
      ticket
    end
  end

  # Highest-numbered untouched placeholders go first. Checked-in or renamed
  # passes belong to real people now, so they are never removed.
  def removable_passes(passes, count)
    passes.reverse
          .select { |t| !t.checked_in? && !t.scanned? && t.attendee_name.match?(PLACEHOLDER_NAME) }
          .first(count)
  end

  def removal_error(found, wanted)
    "Can only remove #{found} of #{wanted} pass(es): the rest are checked in or renamed"
  end

  # Placeholder names carry the pack total ("Pax 1/6"); keep them in step.
  def renumber(remaining)
    remaining.each do |ticket|
      next unless ticket.attendee_name.match?(PLACEHOLDER_NAME)

      ticket.update_column(:attendee_name, ticket.attendee_name.sub(%r{/\d+\z}, "/#{@quantity}"))
    end
  end
end
