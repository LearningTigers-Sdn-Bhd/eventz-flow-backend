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

      @assignment = TableAssignment.find_or_initialize_by(participant_type => participant)
      @assignment.plan_object = plan_object

      if @assignment.save
        render json: @assignment, status: @assignment.previously_new_record? ? :created : :ok
      else
        render json: { errors: @assignment.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      if params[:visitor_id].present?
        @assignment = TableAssignment.find_by!(visitor_id: params[:visitor_id])
      elsif params[:ticket_id].present?
        @assignment = TableAssignment.find_by!(ticket_id: params[:ticket_id])
      else
        return render json: { error: "ticket_id or visitor_id is required" }, status: :unprocessable_entity
      end

      @assignment.destroy
      head :no_content
    end

    private

    def set_plan
      @plan = Plan.find(params[:plan_id])
    end
  end
end