module V1
  class SeatingGroupsController < ApplicationController
    before_action :set_plan
    before_action :set_group, only: [:update, :destroy, :add_member, :remove_member, :assign_to_table]

    def index
      groups = EventSeatingGroup
        .visible_for_plan(@plan)
        .includes(event_seating_group_members: :participant)
        .order(created_at: :asc)

      render json: groups.map { |group| group_json(group) }
    end

    def create
      @group = @plan.event.event_seating_groups.build(group_params)
      @group.plan = @plan if @group.plan_only?

      if @group.save
        render json: group_json(@group), status: :created
      else
        render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def update
      scoped_params = group_params
      if scoped_params[:scope].to_s == "plan_only"
        scoped_params[:plan_id] = @plan.id
      elsif scoped_params[:scope].to_s == "event_level"
        scoped_params[:plan_id] = nil
      end

      if @group.update(scoped_params)
        render json: group_json(@group)
      else
        render json: { errors: @group.errors.full_messages }, status: :unprocessable_entity
      end
    end

    def destroy
      @group.destroy
      head :no_content
    end

    def add_member
      participant = find_participant!
      existing_member = EventSeatingGroupMember.find_by(
        participant_type: participant.class.name,
        participant_id: participant.id
      )

      member =
        if existing_member
          existing_member.update!(event_seating_group: @group)
          existing_member
        else
          @group.event_seating_group_members.create!(participant: participant)
        end

      render json: member_json(member), status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end

    def remove_member
      member = @group.event_seating_group_members.find(params[:member_id])
      member.destroy
      head :no_content
    end

    def assign_to_table
      table = @plan.plan_objects.object_type_table.find(params[:plan_object_id])
      members = @group.event_seating_group_members.includes(:participant)
      participants = members.map(&:participant).compact

      existing_on_target = participants.count do |participant|
        assignment = participant.table_assignments.joins(:plan_object)
                                .where(plan_objects: { plan_id: @plan.id })
                                .first
        assignment&.plan_object_id == table.id
      end

      required_seats = participants.size - existing_on_target
      remaining_seats = [table.capacity.to_i - (table.table_assignments.count - existing_on_target), 0].max

      if required_seats > remaining_seats
        needed_to_fit = required_seats - remaining_seats
        message = "Insufficient space for group of #{participants.size}. Table has #{remaining_seats} seat(s) remaining. Clear #{needed_to_fit} seat(s) to fit."
        return render json: {
          error: "insufficient_space",
          message: message,
          required_seats: required_seats,
          remaining_seats: remaining_seats,
          needed_to_fit: needed_to_fit
        }, status: :unprocessable_entity
      end

      ActiveRecord::Base.transaction do
        participants.each do |participant|
          assignment = participant.table_assignments.joins(:plan_object)
                                  .where(plan_objects: { plan_id: @plan.id })
                                  .first || TableAssignment.new
          assignment.plan_object = table
          if participant.is_a?(Ticket)
            assignment.ticket = participant
          else
            assignment.visitor = participant
          end
          assignment.save!
        end
      end

      render json: {
        success: true,
        group_id: @group.id,
        assigned_count: participants.size,
        plan_object_id: table.id
      }
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: [e.message] }, status: :unprocessable_entity
    end

    private

    def set_plan
      @plan = Plan.find(params[:plan_id])
    end

    def set_group
      groups = EventSeatingGroup.visible_for_plan(@plan)
      @group = groups.find(params[:id])
    end

    def group_params
      params.require(:seating_group).permit(:name, :notes, :scope)
    end

    def find_participant!
      participant_type = params.require(:participant_type).to_s
      participant_id = params.require(:participant_id)

      unless EventSeatingGroupMember::PARTICIPANT_TYPES.include?(participant_type)
        raise ActiveRecord::RecordNotFound, "Invalid participant type"
      end

      participant = participant_type.constantize.find(participant_id)
      if participant.event_id != @plan.event_id
        raise ActiveRecord::RecordNotFound, "Participant does not belong to this event"
      end

      participant
    end

    def group_json(group)
      {
        id: group.id,
        event_id: group.event_id,
        plan_id: group.plan_id,
        scope: group.scope,
        name: group.name,
        notes: group.notes,
        members: group.event_seating_group_members.includes(:participant).map { |member| member_json(member) },
        created_at: group.created_at,
        updated_at: group.updated_at
      }
    end

    def member_json(member)
      participant = member.participant
      {
        id: member.id,
        participant_type: member.participant_type,
        participant_id: member.participant_id,
        participant_name: participant_name(participant)
      }
    end

    def participant_name(participant)
      return participant.attendee_name if participant.is_a?(Ticket)
      return participant.full_name if participant.is_a?(Visitor)

      nil
    end
  end
end
