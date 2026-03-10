module V1
  class PlansController < ApplicationController
    before_action :set_event, only: [:index, :create]
    before_action :set_plan, only: [:show, :update, :destroy, :auto_distribute]

    def index
      @plans = @event.plans
      render json: @plans
    end

    def show
      render json: @plan.as_json(include: {
        plan_objects: {
          include: {
            table_assignments: {
              include: [:ticket, :visitor]
            }
          }
        }
      })
    end

    def create
      @plan = @event.plans.new(plan_params)
      if @plan.save
        render json: @plan, status: :created
      else
        render json: { errors: @plan.errors }, status: :unprocessable_entity
      end
    end

    def update
      if @plan.update(plan_params)
        render json: @plan
      else
        render json: { errors: @plan.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      @plan.destroy
      head :no_content
    end

    def auto_distribute
      service = AutoDistributeService.new(@plan)
      result = service.call
      render json: result
    end

    def export
      pdf_data = PlanPdfGenerator.new(@plan).generate
      send_data pdf_data, 
        filename: "plan_#{@plan.id}.pdf", 
        type: "application/pdf", 
        disposition: "inline"
    end

    private

    def set_event
      @event = Event.friendly.find(params[:event_id])
    end

    def set_plan
      @plan = Plan.find(params[:id])
    end

    def plan_params
      params.require(:plan).permit(:name, :canvas_width, :canvas_height, :pixels_per_unit, :public_enabled, :settings_json)
    end
  end
end
