module V1
  class AiIntegrationsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_ai_integration, only: %i[update destroy available_models]

    def index
      authorize AiIntegration
      integrations = AiIntegration.includes(:ai_models).order(id: :desc)
      render json: integrations.map { |integration| integration_response(integration) }, status: :ok
    end

    def create
      integration = AiIntegration.new(ai_integration_params)
      authorize integration

      if integration.save
        render json: integration_response(integration), status: :created
      else
        render json: { error: 'Validation failed', errors: integration.errors.full_messages },
               status: :unprocessable_content
      end
    end

    def update
      authorize @ai_integration

      if @ai_integration.update(ai_integration_params)
        render json: integration_response(@ai_integration), status: :ok
      else
        render json: { error: 'Validation failed', errors: @ai_integration.errors.full_messages },
               status: :unprocessable_content
      end
    end

    def destroy
      authorize @ai_integration
      @ai_integration.destroy
      head :no_content
    end

    def available_models
      authorize @ai_integration
      render json: AiIntegrations::AvailableModelsFetcher.call(@ai_integration), status: :ok
    rescue AiIntegrations::AvailableModelsFetcher::Error
      render json: { message: 'Unable to load available models' }, status: :bad_gateway
    end

    private

    def set_ai_integration
      @ai_integration = AiIntegration.find(params[:id])
    end

    def ai_integration_params
      permitted = params.require(:ai_integration).permit(:provider, :api_url, :api_key)
      permitted.delete(:api_key) if permitted[:api_key].blank?
      permitted
    end

    def integration_response(integration)
      {
        id: integration.id,
        provider: integration.provider,
        api_url: integration.api_url,
        has_api_key: integration.api_key.present?,
        models: integration.ai_models.order(:id).map { |model| model_response(model) },
        created_at: integration.created_at,
        updated_at: integration.updated_at
      }
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
