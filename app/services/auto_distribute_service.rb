class AutoDistributeService
  def initialize(plan)
    @plan = plan
    # Fetch tables, ordered by z_index for consistent filling order
    @tables = plan.plan_objects.object_type_table.order(z_index: :asc)
    
    # Fetch unassigned tickets for the event
    # Using 'active' scope to ensure we don't assign canceled/refunded tickets
    @unassigned_tickets = plan.event.tickets.active.unassigned
  end

  def call
    # 1. Group tickets by transaction_id (to keep purchases together)
    # Tickets without transaction_id are treated as individual groups
    grouped_tickets = @unassigned_tickets.group_by { |t| t.transaction_id || "single_#{t.id}" }
                                         .values
                                         .sort_by { |members| -members.size }
    
    ActiveRecord::Base.transaction do
      grouped_tickets.each do |members|
        # 2. Try to find a single table that fits the WHOLE group
        target_table = find_perfect_fit_table(members.size)
        
        if target_table
          assign_tickets_to_table(members, target_table)
        else
          # 3. If no single table fits, split the group across the emptiest available tables
          split_group_across_tables(members)
        end
      end
    end
    
    # Return result summary
    {
      assigned_count: @plan.plan_objects.sum { |po| po.table_assignments.count },
      remaining_unassigned: @plan.event.tickets.active.unassigned.count
    }
  end

  private

  # Find first table with enough *remaining* capacity
  def find_perfect_fit_table(needed_seats)
    @tables.each do |table|
      # We must calculate remaining capacity dynamically as we fill tables
      remaining_capacity = table.capacity - table.table_assignments.count
      return table if remaining_capacity >= needed_seats
    end
    nil
  end

  # Distribute members one-by-one into the first available table
  # This maximizes group cohesion (fills one table before moving to next)
  def split_group_across_tables(members)
    members.each do |ticket|
      # Re-calculate best table for every ticket in case capacity shifted
      # Find first table with ANY space
      best_table = @tables.find { |t| (t.capacity - t.table_assignments.count) > 0 }
      
      if best_table
        assign_tickets_to_table([ticket], best_table)
      end
    end
  end

  def assign_tickets_to_table(tickets, table)
    tickets.each do |ticket|
      TableAssignment.create!(ticket: ticket, plan_object: table)
    end
  end
end
