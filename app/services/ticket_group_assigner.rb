# Splits an event's paid tickets across its ticket groups.
#
# 1. target = ceil(total / groups)
# 2. Each group takes its priority ticket types first, in the order they are
#    listed, up to target. Rank by rank (every group's 1st type, then every
#    group's 2nd...); groups sharing a type at the same rank take turns,
#    smallest first.
# 3. Everything left (priority overflow + other types) goes one by one to
#    the group with the fewest tickets, so sizes end within 1 of each other.
#    Balance beats priority.
#
# mode :new  - only unassigned tickets move; existing assignments count toward size.
# mode :all  - every eligible ticket is re-sorted from scratch.
class TicketGroupAssigner
  # added_by_type: { group_id => { ticket_type_id => n } } for tickets arriving in a group.
  Result = Struct.new(:assignments, :counts, :by_type, :added_by_type, keyword_init: true)

  def self.eligible(event)
    event.tickets.active.where(payment_status: :paid, waiting_list: false)
  end

  # Saves a #call result onto the tickets.
  def self.apply!(result)
    result.assignments.group_by(&:last).each do |group_id, pairs|
      Ticket.where(id: pairs.map(&:first)).update_all(ticket_group_id: group_id, updated_at: Time.current)
    end
    result
  end

  # Places every unassigned eligible ticket; never moves an assigned one.
  def self.assign_new!(event)
    apply!(new(event, mode: :new).call)
  end

  def initialize(event, mode: :new)
    @groups = event.ticket_groups.to_a
    @tickets = self.class.eligible(event).pluck(:id, :ticket_type_id, :ticket_group_id)
    @mode = mode.to_sym
  end

  # Returns Result; assignments is { ticket_id => group_id } for tickets that change.
  def call
    return Result.new(assignments: {}, counts: {}, by_type: {}, added_by_type: {}) if @groups.empty?

    counts = @groups.to_h { |g| [g.id, 0] }
    final = {}
    pending = []
    @tickets.each do |id, type_id, group_id|
      if @mode == :new && counts.key?(group_id)
        counts[group_id] += 1
        final[id] = [group_id, type_id]
      else
        pending << [id, type_id]
      end
    end

    target = (@tickets.size / @groups.size.to_f).ceil
    assign = ->(ticket, group) {
      counts[group.id] += 1
      final[ticket[0]] = [group.id, ticket[1]]
    }

    (@groups.map { |g| g.priority_ticket_type_ids.size }.max || 0).times do |rank|
      @groups.select { |g| g.priority_ticket_type_ids[rank] }.group_by { |g| g.priority_ticket_type_ids[rank] }.each do |type_id, groups|
        pending.select { |_, t| t == type_id }.each do |ticket|
          group = groups.select { |g| counts[g.id] < target }.min_by { |g| [counts[g.id], g.position] }
          break unless group

          assign.call(ticket, group)
          pending.delete(ticket)
        end
      end
    end

    pending.sort_by { |id, type_id| [type_id, id] }.each do |ticket|
      assign.call(ticket, @groups.min_by { |g| [counts[g.id], g.position] })
    end

    current = @tickets.to_h { |id, _, group_id| [id, group_id] }
    assignments = final.transform_values(&:first).reject { |id, gid| current[id] == gid }
    Result.new(
      assignments: assignments,
      counts: counts,
      by_type: final.values.group_by(&:first).transform_values { |v| v.map(&:last).tally },
      added_by_type: assignments.group_by(&:last).transform_values { |pairs| pairs.map { |id, _| final[id].last }.tally }
    )
  end
end
