class V1::UsersController < ApplicationController
  # Skip JWT check for registration
  skip_before_action :authenticate_request!, only: [:create]

  # POST /v1/users (Registration)
  def create
    # Default role is 'member' as set in the model
    @user = User.new(user_params)
    
    # Authorize the action using the UserPolicy (even though it's registration, 
    # the policy will ensure only 'member' role can be created)
    authorize @user, policy_class: UserPolicy 

    if @user.save
      token = JsonWebToken.encode(user_id: @user.id)
      render json: { user: @user.slice(:id, :full_name, :email, :role), token: token }, status: :created
    else
      render json: { errors: @user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # GET /v1/users/profile (Show Profile)
  def show
    # current_user is set by authenticate_request!
    authorize current_user, policy_class: UserPolicy 
    render json: current_user.slice(:id, :full_name, :email, :role), status: :ok
  end

  # PUT/PATCH /v1/users/profile (Update Profile)
  def update
    authorize current_user, policy_class: UserPolicy

    # Ensure user can only update safe fields like name, password, but not role.
    if current_user.update(update_user_params)
      render json: current_user.slice(:id, :full_name, :email, :role), status: :ok
    else
      render json: { errors: current_user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Params for registration (includes password for has_secure_password)
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :full_name, :phone)
  end
  
  # Params for updating profile (does not require full password set unless changing password)
  def update_user_params
    params.require(:user).permit(:full_name, :phone, :password, :password_confirmation)
  end
end