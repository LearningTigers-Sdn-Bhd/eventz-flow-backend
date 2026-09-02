module V1
  class PlansController < ApplicationController
    before_action :set_event, only: [:index, :create]
    before_action :set_plan, only: [:show, :update, :destroy, :auto_distribute, :sync_table_numbers, :export]
    before_action :set_active_storage_host, only: [:show, :index]

    def index
      @plans = @event.plans
      plans_json = @plans.as_json.map do |plan_json|
        plan = @plans.find(plan_json['id'])
        plan_json.merge(
          tables_count: plan.plan_objects.object_type_table.count,
          total_capacity: plan.plan_objects.object_type_table.sum(:capacity),
          assigned_guests_count: plan.table_assignments.count
        )
      end
      render json: plans_json
    end

    def show
      set_active_storage_host
      plan_json = @plan.as_json(include: {
        plan_objects: {
          include: {
            table_assignments: {
              include: [:ticket, :visitor]
            }
          }
        }
      })

      # Add image URLs to plan objects
      plan_json['plan_objects'] = plan_json['plan_objects'].map do |obj_json|
        obj = @plan.plan_objects.find(obj_json['id'])
        obj_json.merge(
          image_url: obj.image.attached? ? url_for(obj.image) : nil
        )
      end

      render json: plan_json.merge(
        background_image_url: @plan.background_image.attached? ? url_for(@plan.background_image) : nil,
        background_image_metadata: @plan.background_image.attached? ? @plan.background_image.metadata : nil
      )
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
        # If image was just uploaded and canvas is 0, auto-set from image metadata
        if @plan.background_image.attached? && (@plan.canvas_width == 0 || @plan.canvas_width.nil?)
          # Force analysis if not already done
          @plan.background_image.analyze unless @plan.background_image.analyzed?
          metadata = @plan.background_image.metadata
          if metadata[:width] && metadata[:height]
            @plan.update(canvas_width: metadata[:width], canvas_height: metadata[:height])
          end
        end

        set_active_storage_host
        render json: @plan.as_json.merge(
          background_image_url: @plan.background_image.attached? ? url_for(@plan.background_image) : nil,
          background_image_metadata: @plan.background_image.attached? ? @plan.background_image.metadata : nil
        )
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

    def sync_table_numbers
      service = TableNumberSyncService.new(@plan, field_key: params[:field_key])
      result = service.call
      render json: result
    end

    def export
      pdf_data = PlanPdfGenerator.new(@plan).generate(type: params[:type])
      send_data pdf_data, 
        filename: "plan_#{@plan.id}_#{params[:type] || 'map'}.pdf", 
        type: "application/pdf", 
        disposition: "inline"
    end

    private

    def set_active_storage_host
      ActiveStorage::Current.url_options = { host: request.base_url }
    end

    def set_event
      @event = Event.friendly.find(params[:event_id])
    end

    def set_plan
      @plan = Plan.find(params[:id])
    end

    def plan_params
      params.require(:plan).permit(:name, :canvas_width, :canvas_height, :pixels_per_unit, :public_enabled, :settings_json, :background_image)
    end
  end
end
