class V1::TeamMembersController < ApplicationController
  before_action :set_team_member, only: [:show, :update, :toggle_status, :destroy]
  # before_action :authorize_org_owner!, except: [:index, :show]

  # GET /v1/team_members
  def index
    # Only org_owner and managers can view team members
    # unless current_user.is_manager_or_higher?
    #   return render json: { error: 'Forbidden' }, status: :forbidden
    # end

    @team_members = User.where.not(id: current_user.id).order(created_at: :desc)
    render json: @team_members.map { |user| format_user(user) }, status: :ok
  end

  # GET /v1/team_members/:id
  def show
    # Users can view their own profile, or org_owner/manager can view anyone
    # unless current_user.id == @team_member.id || current_user.is_manager_or_higher?
    #   return render json: { error: 'Forbidden' }, status: :forbidden
    # end

    render json: format_user(@team_member), status: :ok
  end

  # POST /v1/team_members
  def create
    @team_member = User.new(team_member_create_params)

    if @team_member.save
      render json: format_user(@team_member), status: :created
    else
      render json: { error: 'Validation failed', errors: @team_member.errors.full_messages }, 
             status: :unprocessable_entity
    end
  end

  # PUT/PATCH /v1/team_members/:id
  def update
    if @team_member.update(team_member_update_params)
      render json: format_user(@team_member), status: :ok
    else
      render json: { error: 'Validation failed', errors: @team_member.errors.full_messages }, 
             status: :unprocessable_entity
    end
  end

  # PATCH /v1/team_members/:id/toggle_status
  def toggle_status
    unless params[:status].in?(['active', 'inactive'])
      return render json: { error: 'Invalid status value' }, status: :unprocessable_entity
    end

    if @team_member.update(status: params[:status])
      render json: format_user(@team_member), status: :ok
    else
      render json: { error: 'Validation failed', errors: @team_member.errors.full_messages }, 
             status: :unprocessable_entity
    end
  end

  # DELETE /v1/team_members/:id
  def destroy
    # Prevent deleting yourself
    if @team_member.id == current_user.id
      return render json: { error: 'You cannot delete your own account' }, status: :unprocessable_entity
    end

    @team_member.destroy
    render json: format_user(@team_member), status: :ok
  end

  private

  def set_team_member
    @team_member = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Team member not found' }, status: :not_found
  end

  # def authorize_org_owner!
  #   unless current_user.is_org_owner?
  #     render json: { error: 'Forbidden', message: 'Only organization owners can perform this action' }, 
  #            status: :forbidden
  #   end
  # end

  def team_member_create_params
    params.require(:team_member).permit(
      :full_name, 
      :email, 
      :phone, 
      :password, 
      :password_confirmation, 
      :role
    )
  end

  def team_member_update_params
    permitted = params.require(:team_member).permit(
      :full_name, 
      :email, 
      :phone, 
      :role
    )
    
    # Only include password fields if password is provided
    if params[:team_member][:password].present?
      permitted.merge!(
        params.require(:team_member).permit(:password, :password_confirmation)
      )
    end
    
    permitted
  end

  def format_user(user)
    {
      id: user.id.to_s,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      status: user.status,
      created_at: user.created_at.iso8601,
      updated_at: user.updated_at.iso8601
    }
  end
end
