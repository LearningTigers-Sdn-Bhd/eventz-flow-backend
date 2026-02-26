class AutoDistributeService
  def initialize(plan)
    @plan = plan
    @tables = plan.plan_objects.object_type_table.order(z_index: :asc)
    
    # Fetch all unassigned participants (both tickets and visitors)
    @unassigned_tickets = plan.event.tickets.active.unassigned
    @unassigned_visitors = plan.event.visitors.unassigned
  end

  def call
    # Combine tickets and visitors into a single list of assignables
    all_unassigned = @unassigned_tickets.to_a + @unassigned_visitors.to_a
    
    # Group tickets by transaction_id, visitors are treated as single-member groups
    grouped_participants = all_unassigned.group_by do |participant|
      if participant.is_a?(Ticket) && participant.transaction_id.present?
        "ticket_group_#{participant.transaction_id}"
      else
        "single_#{participant.class.name}_#{participant.id}"
      end
    end.values.sort_by { |members| -members.size }
    
    ActiveRecord::Base.transaction do
      grouped_participants.each do |members|
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
      remaining_unassigned: @plan.event.tickets.active.unassigned.count + @plan.event.visitors.unassigned.count
    }
  end

  private

  def find_perfect_fit_table(needed_seats)
    @tables.find do |table|
      (table.capacity - table.table_assignments.count) >= needed_seats
    end
  end

  def split_group_across_tables(members)
    members.each do |participant|
      best_table = @tables.find { |t| (t.capacity - t.table_assignments.count) > 0 }
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
end
