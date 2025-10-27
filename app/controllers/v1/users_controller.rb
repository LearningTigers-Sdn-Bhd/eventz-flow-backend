# app/controllers/v1/users_controller.rb
module V1
  class UsersController < ApplicationController
    # Skip JWT check for registration
    skip_before_action :authenticate_user!, only: [:create]

    # FIX: Add authorization check to enforce permission rules
    before_action :authorize_org_owner!, only: [:update_role]

    before_action :set_user, only: [:update_role]

    # POST /v1/users (Registration)
    def create
      @user = User.new(user_params)
      authorize @user, policy_class: UserPolicy

      if @user.save
        token = JwtService.encode(user_id: @user.id)
        render json: { user: @user.slice(:id, :full_name, :email, :role), token: token }, status: :created
      else
        render json: { errors: @user.errors.full_messages }, status: :unprocessable_content
      end
    end

    # GET /v1/users/profile (Show Profile)
    def show
      authorize current_user, policy_class: UserPolicy
      success_response(
        data: current_user.slice(:id, :full_name, :email, :role, :phone),
        message: "Profile retrieved successfully"
      )
    end

    # PUT/PATCH /v1/users/profile (Update Profile)
    def update
      authorize current_user, policy_class: UserPolicy

      if current_user.update(update_user_params)
        success_response(
          data: current_user.slice(:id, :full_name, :email, :role, :phone),
          message: "Profile updated successfully"
        )
      else
        error_response(
          message: "Validation failed",
          errors: format_validation_errors(current_user),
          status: :unprocessable_content
        )
      end
    end

    # PUT /v1/users/:id/role (Global Role Management)
    # app/controllers/v1/users_controller.rb
    def update_role
      # Authorization handled by before_action :authorize_org_owner!
      if current_user == @user
        render json: { error: 'Forbidden', message: 'Cannot change your own role via this endpoint.' }, status: :forbidden and return
      end

      begin
        if @user.update(role_params)
          render json: { user: @user.as_json(only: [:id, :email, :role, :full_name]) }, status: :ok
        else
          render json: { error: 'Validation Error', message: @user.errors.full_messages.to_sentence, errors: @user.errors.messages }, status: :unprocessable_content
        end
      rescue ArgumentError => e
        # Handles "is not a valid role"
        render json: { error: 'Validation Error', message: e.message, errors: { role: [e.message] } }, status: :unprocessable_content
      end
    end


    private

    def set_user
      @user = User.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'User not found.' }, status: :not_found
    end

    def authorize_org_owner!
      unless current_user.org_owner?
        render json: { error: 'Forbidden', message: 'Only an organization owner can change global user roles.' }, status: :forbidden
        # CRITICAL FIX: Halt execution after rendering the error
        return
      end
    end

    # Params for registration
    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :full_name, :phone)
    end

    # Params for updating profile
    def update_user_params
      params.require(:user).permit(:full_name, :phone, :password, :password_confirmation)
    end

    # Params for updating role
    def role_params
      params.require(:user).permit(:role)
    end
  end
end
