module V1
  class PlanObjectsController < ApplicationController
    before_action :set_plan, only: [:create, :batch, :batch_create, :batch_destroy]
    before_action :set_plan_object, only: [:destroy]

    def create
      @plan_object = @plan.plan_objects.new(plan_object_params)
      if @plan_object.save
        render json: @plan_object, status: :created
      else
        render json: { errors: @plan_object.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      @plan_object.destroy
      head :no_content
    end

    def batch
      updated_objects = []
      errors = []

      ActiveRecord::Base.transaction do
        if params[:plan_objects].present?
          params[:plan_objects].each do |obj_params|
            permitted = obj_params.permit(:id, :object_type, :layer, :x, :y, :rotation, :width, :height, :path, :label, :capacity, :locked, :z_index, :image)
            # Find object ensuring it belongs to the plan
            obj = @plan.plan_objects.find_by(id: permitted[:id])
            if obj
              unless obj.update(permitted.except(:id))
                errors << { id: obj.id, errors: obj.errors }
              end
              updated_objects << obj
            end
          end
        end

        if errors.any?
          raise ActiveRecord::Rollback
        end
      end

      if errors.any?
        render json: { errors: errors }, status: :unprocessable_entity
      else
        render json: updated_objects
      end
    end

    def batch_create
      created_objects = []
      errors = []

      ActiveRecord::Base.transaction do
        if params[:plan_objects].present?
          params[:plan_objects].each do |obj_params|
            permitted = obj_params.permit(:object_type, :layer, :x, :y, :rotation, :width, :height, :path, :label, :capacity, :locked, :z_index)
            obj = @plan.plan_objects.new(permitted)
            unless obj.save
              errors << { label: obj.label, errors: obj.errors }
            end
            created_objects << obj
          end
        end

        if errors.any?
          raise ActiveRecord::Rollback
        end
      end

      if errors.any?
        render json: { errors: errors }, status: :unprocessable_entity
      else
        render json: created_objects, status: :created
      end
    end

    def batch_destroy
      ids = params[:ids]
      if ids.present?
        objects = @plan.plan_objects.where(id: ids)
        objects.destroy_all
        head :no_content
      else
        render json: { error: "No IDs provided" }, status: :bad_request
      end
    end

    private

    def set_plan
      @plan = Plan.find(params[:plan_id])
    end

    def set_plan_object
      @plan_object = PlanObject.find(params[:id])
    end

    def plan_object_params
      params.require(:plan_object).permit(:object_type, :layer, :x, :y, :rotation, :width, :height, :path, :label, :capacity, :locked, :z_index, :image)
    end
  end
end
