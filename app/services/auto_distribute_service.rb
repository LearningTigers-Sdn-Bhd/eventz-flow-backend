require "set"

class AutoDistributeService
  def initialize(plan)
    @plan = plan
    @tables = plan.plan_objects.object_type_table.order(z_index: :asc)
    @unassigned_tickets = plan.event.tickets.active.unassigned_in_plan(plan).to_a
    @unassigned_visitors = plan.event.visitors.unassigned_in_plan(plan).to_a
    @skipped_groups = []
  end

  def call
    ActiveRecord::Base.transaction do
      assigned_keys = Set.new

      explicit_grouped_participants.each do |group_data|
        members = group_data[:members]
        members.each { |member| assigned_keys << participant_key(member) }

        target_table = find_perfect_fit_table(members.size)
        if target_table
          assign_participants_to_table(members, target_table)
        else
          max_available = @tables.map { |table| available_seats(table) }.max || 0
          @skipped_groups << {
            group_id: group_data[:group].id,
            name: group_data[:group].name,
            size: members.size,
            max_available_table_seats: max_available,
            needed_to_fit: [members.size - max_available, 0].max
          }
        end
      end

      fallback_participants = all_unassigned.reject { |participant| assigned_keys.include?(participant_key(participant)) }
      grouped_fallback_participants(fallback_participants).each do |members|
        target_table = find_perfect_fit_table(members.size)
        if target_table
          assign_participants_to_table(members, target_table)
        else
          split_group_across_tables(members)
        end
      end
    end

    {
      assigned_count: @plan.table_assignments.count,
      remaining_unassigned: @plan.event.tickets.active.unassigned.count + @plan.event.visitors.unassigned.count,
      skipped_groups: @skipped_groups
    }
  end

  private

  def all_unassigned
    @all_unassigned ||= @unassigned_tickets + @unassigned_visitors
  end

  def explicit_grouped_participants
    groups = EventSeatingGroup
      .visible_for_plan(@plan)
      .includes(event_seating_group_members: :participant)
      .order(created_at: :asc)

    groups.filter_map do |group|
      members = group.event_seating_group_members.map(&:participant).compact
      members.select! { |participant| participant_unassigned?(participant) }
      next if members.empty?

      { group: group, members: members }
    end
  end

  def grouped_fallback_participants(participants)
    participants.group_by do |participant|
      if participant.is_a?(Ticket) && fallback_ticket_group_key(participant).present?
        "ticket_group_#{fallback_ticket_group_key(participant)}"
      else
        "single_#{participant.class.name}_#{participant.id}"
      end
    end.values.sort_by { |members| -members.size }
  end

  def fallback_ticket_group_key(ticket)
    if ticket.respond_to?(:transaction_id) && ticket.transaction_id.present?
      return ticket.transaction_id
    end

    ticket.registered_by_email.presence
  end

  def participant_key(participant)
    "#{participant.class.name}-#{participant.id}"
  end

  def participant_unassigned?(participant)
    participant.table_assignments.joins(:plan_object).where(plan_objects: { plan_id: @plan.id }).empty?
  end

  def find_perfect_fit_table(needed_seats)
    @tables.find do |table|
      available_seats(table) >= needed_seats
    end
  end

  def split_group_across_tables(members)
    members.each do |participant|
      best_table = @tables.find { |t| available_seats(t) > 0 }
      assign_participants_to_table([participant], best_table) if best_table
    end
  end

  def assign_participants_to_table(participants, table)
    participants.each do |participant|
      if participant.is_a?(Ticket)
        TableAssignment.create!(ticket: participant, plan_object: table)
      elsif participant.is_a?(Visitor)
        TableAssignment.create!(visitor: participant, plan_object: table)
      end
    end
  end

  def available_seats(table)
    [table.capacity.to_i - table.table_assignments.count, 0].max
  end
end
