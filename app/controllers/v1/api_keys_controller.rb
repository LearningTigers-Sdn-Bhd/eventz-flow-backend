class V1::ApiKeysController < ApplicationController
  before_action :set_api_key, only: [:destroy]
  
  # GET /v1/users/me/api_keys
  def index
    # Current user is set via the JWT authentication middleware
    keys = current_user.api_keys.where(is_active: true).select(:id, :last_used_at, :created_at)
    
    # Send only partial key data for display
    render json: keys.map { |k| k.attributes.merge(truncated_key: "XXXX-#{k.key_hash[-4..-1]}") }, status: :ok
  end

  # POST /v1/users/me/api_keys
  def create
    # 1. Generate the plain text key
    plain_text_key = AuthenticationService.generate_secure_token + SecureRandom.alphanumeric(16)
    hashed_key = AuthenticationService.hash_token(plain_text_key)
    
    # 2. Persist the HASHED key
    api_key = current_user.api_keys.create!(key_hash: hashed_key)

    # 3. Return the key ONCE
    render json: { 
      message: "API Key created. SAVE THIS KEY SOMEWHERE secure. It will not be shown again.",
      api_key: plain_text_key,
      id: api_key.id
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  # DELETE /v1/users/me/api_keys/{id}
  def destroy
    @api_key.update(is_active: false)
    head :no_content
  end
  
  private
  
  def set_api_key
    @api_key = current_user.api_keys.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    head :not_found
  end
end