module V1
  class AiModelsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_ai_integration
    before_action :set_ai_model, only: %i[update destroy set_default]

    def create
      model = @ai_integration.ai_models.build(ai_model_params)
      authorize model

      if model.save
        set_default_if_missing(model)
        render json: model_response(model), status: :created
      else
        render json: { error: 'Validation failed', errors: model.errors.full_messages },
               status: :unprocessable_content
      end
    end

    def import
      authorize @ai_integration, :import_models?

      models = import_models_params.filter_map do |attributes|
        model_id = attributes[:model_id].to_s.strip
        next if model_id.blank?

        {
          model_id: model_id,
          model_name: attributes[:model_name].to_s.strip
        }
      end.uniq { |attributes| attributes[:model_id] }

      if models.empty?
        render json: { error: 'At least one model is required' }, status: :unprocessable_content
        return
      end

      imported_models = AiModel.transaction do
        models.map do |attributes|
          model = @ai_integration.ai_models.find_or_initialize_by(model_id: attributes[:model_id])
          if model.new_record?
            model.display_name = attributes[:model_name]
          elsif model.display_name.blank? && attributes[:model_name].present?
            model.display_name = attributes[:model_name]
          end
          model.save!
          model
        end
      end

      set_default_if_missing(imported_models.first)
      render json: imported_models.map { |model| model_response(model) }, status: :created
    rescue ActiveRecord::RecordInvalid
      render json: { error: 'Validation failed' }, status: :unprocessable_content
    end

    def update
      authorize @ai_model

      if @ai_model.update(ai_model_params)
        render json: model_response(@ai_model), status: :ok
      else
        render json: { error: 'Validation failed', errors: @ai_model.errors.full_messages },
               status: :unprocessable_content
      end
    end

    def destroy
      authorize @ai_model
      @ai_model.destroy
      head :no_content
    end

    def set_default
      authorize @ai_model
      @ai_model.make_default!
      render json: model_response(@ai_model), status: :ok
    end

    private

    def set_ai_integration
      @ai_integration = AiIntegration.find(params[:ai_integration_id])
    end

    def set_ai_model
      @ai_model = @ai_integration.ai_models.find(params[:id])
    end

    def ai_model_params
      permitted = params.require(:ai_model).permit(:model_id, :model_name)
      if permitted.key?(:model_name) || action_name == 'create'
        permitted[:display_name] = permitted.delete(:model_name).to_s
      end
      permitted
    end

    def import_models_params
      params.require(:ai_models).permit(models: %i[model_id model_name]).fetch(:models, [])
    end

    def set_default_if_missing(model)
      return if model.blank? || AiModel.where(is_default: true).exists?

      model.make_default!
    end

    def model_response(model)
      {
        id: model.id,
        ai_integration_id: model.ai_integration_id,
        model_id: model.model_id,
        model_name: model.display_name,
        is_default: model.is_default,
        created_at: model.created_at,
        updated_at: model.updated_at
      }
    end
  end
end
