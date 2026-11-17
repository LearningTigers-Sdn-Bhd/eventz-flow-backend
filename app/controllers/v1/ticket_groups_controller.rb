module V1
  # Splits an event's paid tickets into rooms/groups (BTH Summit: 4 rooms).
  class TicketGroupsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :require_feature

    # GET /v1/events/:event_id/ticket_groups
    def index
      authorize_groups(:index?)
      render json: payload
    end

    # POST /v1/events/:event_id/ticket_groups/setup  { count: 4 } - adds `count` more groups
    def setup
      authorize_groups(:setup?)
      count = params[:count].to_s.to_i
      return render json: { error: 'count must be 1-20' }, status: :unprocessable_content unless count.between?(1, 20)

      last = @event.ticket_groups.maximum(:position) || 0
      (last + 1..last + count).each { |n| @event.ticket_groups.create!(name: "Group #{n}", position: n) }
      render json: payload
    end

    # PATCH /v1/events/:event_id/ticket_groups/:id  { name, priority_ticket_type_ids: [] }
    def update
      group = @event.ticket_groups.find(params[:id])
      authorize group, :update?
      if group.update(params.permit(:name, priority_ticket_type_ids: []))
        render json: payload
      else
        render json: { errors: group.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/ticket_groups/:id - its tickets become unassigned
    def destroy
      group = @event.ticket_groups.find(params[:id])
      authorize group, :destroy?
      group.destroy!
      render json: payload
    end

    # POST /v1/events/:event_id/ticket_groups/preview  { mode: new|all }
    def preview
      authorize_groups(:preview?)
      render json: summarize(TicketGroupAssigner.new(@event, mode: mode).call)
    end

    # POST /v1/events/:event_id/ticket_groups/assign  { mode: new|all }
    def assign
      authorize_groups(:assign?)
      result = TicketGroupAssigner.new(@event, mode: mode).call
      TicketGroupAssigner.apply!(result)
      render json: payload.merge(assigned: result.assignments.size)
    end

    # PATCH /v1/events/:event_id/ticket_groups/move  { public_ids: [], ticket_group_id: id|null }
    def move
      authorize_groups(:move?)
      # The id is cast to an integer before any lookup: a JSON array or hash here
      # must never reach `exists?`, which would read it as a raw SQL condition.
      raw = params[:ticket_group_id]
      group = raw.present? ? @event.ticket_groups.find_by(id: Integer(raw.to_s, exception: false)) : nil
      return render json: { error: 'Group not found' }, status: :not_found if raw.present? && group.nil?

      public_ids = Array(params[:public_ids]).map(&:to_s)
      moved = @event.tickets.where(public_id: public_ids).update_all(ticket_group_id: group&.id, updated_at: Time.current)
      render json: payload.merge(moved: moved)
    end

    private

    def set_event
      @event = Event.with_deleted.find(params[:event_id])
    end

    def require_feature
      return if @event.use_ticket_groups?

      render json: { error: 'Ticket groups are not enabled for this event' }, status: :forbidden
    end

    # Collection actions have no group yet, so the policy gets a blank one for this event.
    def authorize_groups(action)
      authorize TicketGroup.new(event: @event), action
    end

    def mode
      params[:mode] == 'all' ? :all : :new
    end

    def payload
      counts = TicketGroupAssigner.eligible(@event).group(:ticket_group_id).count
      by_type = TicketGroupAssigner.eligible(@event).group(:ticket_group_id, :ticket_type_id).count
                                   .each_with_object(Hash.new { |h, k| h[k] = {} }) { |((gid, type_id), n), h| h[gid][type_id] = n }
      {
        groups: TicketGroupSerializer.rows(@event.ticket_groups, counts, by_type),
        unassigned_count: counts[nil] || 0,
        unassigned_by_type: by_type[nil] || {}
      }
    end

    def summarize(result)
      groups = @event.ticket_groups.index_by(&:id)
      current = TicketGroupAssigner.eligible(@event).group(:ticket_group_id).count
      {
        moves: result.assignments.size,
        groups: result.counts.map do |gid, count|
          added = result.added_by_type[gid] || {}
          {
            id: gid, name: groups[gid].name, count: count, current_count: current[gid] || 0,
            added: added.values.sum, added_by_type: added, by_type: result.by_type[gid] || {}
          }
        end
      }
    end
  end
end
