module V1
  class BoothPlansController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event_and_authorize
    before_action :set_booth_plan, only: %i[show update destroy]

    # GET /v1/events/:event_id/booth_plans
    def index
      @booth_plans = policy_scope(@event.booth_plans).ordered
      render json: @booth_plans.map { |plan| format_booth_plan(plan) }, status: :ok
    end

    # GET /v1/events/:event_id/booth_plans/:id
    def show
      render json: format_booth_plan(@booth_plan), status: :ok
    end

    # POST /v1/events/:event_id/booth_plans
    def create
      authorize @event, :update?

      @booth_plan = @event.booth_plans.build(booth_plan_params)
      unless params.dig(:booth_plan, :position).present?
        @booth_plan.position = (@event.booth_plans.maximum(:position) || -1) + 1
      end

      if @booth_plan.save
        render json: format_booth_plan(@booth_plan), status: :created
      else
        render json: { errors: @booth_plan.errors.full_messages }, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:event_id/booth_plans/:id
    def update
      authorize @event, :update?

      if @booth_plan.update(booth_plan_params)
        render json: format_booth_plan(@booth_plan), status: :ok
      else
        render json: { errors: @booth_plan.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/booth_plans/:id
    def destroy
      authorize @event, :update?

      @booth_plan.destroy
      head :no_content
    end

    private

    def set_event
      @event = Event.with_deleted.find(params[:event_id])
    end

    def set_event_and_authorize
      set_event
      authorize @event, :show?
    end

    def set_booth_plan
      @booth_plan = @event.booth_plans.find(params[:id])
    end

    def booth_plan_params
      params.require(:booth_plan).permit(:name, :position, :active, :image)
    end

    def format_booth_plan(plan)
      {
        id: plan.id,
        event_id: plan.event_id,
        name: plan.name,
        position: plan.position,
        active: plan.active,
        image_url: plan.image.attached? ? url_for(plan.image) : nil,
        created_at: plan.created_at,
        updated_at: plan.updated_at
      }
    end
  end
end
