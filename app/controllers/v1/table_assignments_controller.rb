module V1
  class TableAssignmentsController < ApplicationController
    before_action :set_plan, only: [:create]

    def create
      if params[:ticket_id].present?
        participant = Ticket.find(params[:ticket_id])
        participant_type = :ticket
      elsif params[:visitor_id].present?
        participant = Visitor.find(params[:visitor_id])
        participant_type = :visitor
      else
        return render json: { error: "ticket_id or visitor_id is required" }, status: :unprocessable_entity
      end
      
      if participant.event_id != @plan.event_id
        return render json: { error: "Participant does not belong to this event" }, status: :unprocessable_entity
      end

      plan_object = @plan.plan_objects.find(params[:plan_object_id])

      @assignment = TableAssignment.joins(:plan_object)
                                  .where(plan_objects: { plan_id: @plan.id })
                                  .find_or_initialize_by(participant_type => participant)
      
      @assignment.plan_object = plan_object

      if @assignment.save
        render json: @assignment, status: @assignment.previously_new_record? ? :created : :ok
      else
        render_assignment_errors(@assignment)
      end
    end

    def update
      @assignment = find_assignment

      if @assignment.update(assignment_params)
        render json: @assignment, status: :ok
      else
        render_assignment_errors(@assignment)
      end
    end

    def destroy
      @assignment = find_assignment

      @assignment.destroy
      head :no_content
    end

    private

    def set_plan
      @plan = Plan.find(params[:plan_id])
    end

    def find_assignment
      scope = TableAssignment.all
      if params[:plan_id].present?
        scope = scope.joins(:plan_object).where(plan_objects: { plan_id: params[:plan_id] })
      end

      if params[:visitor_id].present?
        scope.find_by!(visitor_id: params[:visitor_id])
      elsif params[:ticket_id].present?
        scope.find_by!(ticket_id: params[:ticket_id])
      else
        raise ActiveRecord::RecordNotFound
      end
    end

    def assignment_params
      params.require(:assignment).permit(:notes, :arrived_at)
    end

    def render_assignment_errors(assignment)
      payload = assignment.insufficient_space_payload(required_seats: 1)
      has_insufficient_space_error = assignment.errors.details.fetch(:base, []).any? do |detail|
        detail[:error] == :insufficient_space
      end

      if has_insufficient_space_error
        render json: payload, status: :unprocessable_entity
      else
        render json: { errors: assignment.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
