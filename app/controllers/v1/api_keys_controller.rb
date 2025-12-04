# app/controllers/v1/api_keys_controller.rb [Original Code]
module V1
  class ApiKeysController < ApplicationController

    # We rely on Pundit to enforce that only org_owners and organizers can perform these actions.
    # The current_user must be authenticated via the JWT before these actions run.
    before_action :set_api_key, only: [:destroy]

    # GET /v1/api_keys
    def index
      # 1. Authorize access to the index action (Policy: user must be org_owner)
      @api_keys = policy_scope(ApiKey)
      authorize ApiKey # Authorize the class/scope

      # 2. Render only safe metadata (ID, name, timestamps).
      # Truncating a hash is not helpful or secure.
      render json: @api_keys.as_json(only: [:id, :name, :is_active, :last_used_at, :created_at]), status: :ok
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Forbidden' }, status: :forbidden
    end

    # POST /v1/api_keys
    def create
      # 1. Build the key for the current user (model handles generation and hashing)
      @api_key = current_user.api_keys.build(api_key_params)
      authorize @api_key # Authorize creation (Policy: user must be org_owner or organizer)

      # 2. Save the API key (triggers generation via callback)
      if @api_key.save
        # 3. Return the key ONCE
        render json: {
          id: @api_key.id,
          name: @api_key.name,
          is_active: @api_key.is_active,
          raw_key: @api_key.raw_key,
          message: "API Key created. SAVE THIS KEY, it will not be shown again."
        }, status: :created
      else
        render json: { errors: @api_key.errors.full_messages }, status: :unprocessable_content
      end
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Forbidden' }, status: :forbidden
    end

    # DELETE /v1/api_keys/:id (Revocation)
    def destroy
      authorize @api_key # Authorize destruction (Policy: user must be org_owner or organizer)

      # Use the model instance method to update is_active: false
      if @api_key.revoke!
        head :no_content
      else
        render json: { error: 'Failed to revoke key.' }, status: :unprocessable_content
      end
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Forbidden' }, status: :forbidden
    end

    private

    def set_api_key
      # Only allow a user to modify their own keys
      @api_key = current_user.api_keys.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found' }, status: :not_found
    end

    def api_key_params
      params.permit(:name)
    end
  end
end
