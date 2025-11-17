class V1::TeamMembersController < ApplicationController
  before_action :set_team_member, only: [:show, :update, :toggle_status, :destroy]
  before_action :authorize_manage_team_member!, only: [:update, :toggle_status, :destroy]
  # before_action :authorize_org_owner!, except: [:index, :show]

  # GET /v1/team_members
  def index
    @team_members = team_members_for_current_user
                      .order(created_at: :desc)

    render json: @team_members.map { |user| format_user(user) }, status: :ok
  end

  # GET /v1/team_members/organizer/:organizer_id
  def organizer_members
    return render_forbidden unless current_user.org_owner?

    organizer = User.find(params[:organizer_id])
    return render_not_an_organizer unless organizer.organizer?

    @team_members = organizer.created_users
                             .where(role: :member)
                             .order(created_at: :desc)

    render json: @team_members.map { |user| format_user(user) }, status: :ok
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Organizer not found' }, status: :not_found
  end

  # GET /v1/team_members/:id
  def show
    # Users can view their own profile, or org_owner/organizer can view anyone
    # unless current_user.id == @team_member.id || current_user.is_organizer_or_higher?
    #   return render json: { error: 'Forbidden' }, status: :forbidden
    # end

    render json: format_user(@team_member), status: :ok
  end

  # POST /v1/team_members
  def create
    @team_member = User.new(team_member_create_params.merge(created_by_id: current_user.id))

    if @team_member.save
      render json: format_user(@team_member), status: :created
    else
      render json: { error: 'Validation failed', errors: @team_member.errors.full_messages },
             status: :unprocessable_content
    end
  end

  # PUT/PATCH /v1/team_members/:id
  def update
    if @team_member.update(team_member_update_params)
      render json: format_user(@team_member), status: :ok
    else
      render json: { error: 'Validation failed', errors: @team_member.errors.full_messages },
             status: :unprocessable_content
    end
  end

  # PATCH /v1/team_members/:id/toggle_status
  def toggle_status
    return render_invalid_status unless valid_status?(params[:status])

    if @team_member.update(status: params[:status])
      render json: format_user(@team_member), status: :ok
    else
      render json: { error: 'Validation failed', errors: @team_member.errors.full_messages },
             status: :unprocessable_content
    end
  end

  # DELETE /v1/team_members/:id
  def destroy
    return render_cannot_delete_self if deleting_self?

    @team_member.destroy
    render json: format_user(@team_member), status: :ok
  end

  private

  # === Query Methods ===

  def team_members_for_current_user
    return User.none unless current_user.org_owner? || current_user.organizer?

    if current_user.org_owner?
      org_owner_visible_users
    else
      current_user.created_users
    end
  end

  def org_owner_visible_users
    User.where.not(id: current_user.id)
        .where(
          User.arel_table[:role].in([:org_owner, :organizer])
            .or(
              User.arel_table[:role].eq(:member)
                .and(
                  User.arel_table[:created_by_id].eq(nil)
                    .or(User.arel_table[:created_by_id].eq(current_user.id))
                )
            )
        )
  end

  # === Finder Methods ===

  def set_team_member
    @team_member = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Team member not found' }, status: :not_found
  end

  # === Validation Methods ===

  def authorize_manage_team_member!
    return render_forbidden unless can_manage_team_member?(@team_member)
  end

  def can_manage_team_member?(member)
    return false if member.nil?
    
    if current_user.org_owner?
      # Org owners are system admins - they can manage everyone
      return true
    elsif current_user.organizer?
      # Organizers can only manage members they created
      member.member? && member.created_by_id == current_user.id
    else
      false
    end
  end

  def valid_status?(status)
    User.statuses.key?(status)
  end

  def deleting_self?
    @team_member.id == current_user.id
  end

  # === Rendering Methods ===

  def render_forbidden
    render json: { error: 'Forbidden' }, status: :forbidden
  end

  def render_not_an_organizer
    render json: { error: 'User is not an organizer' }, status: :unprocessable_content
  end

  def render_invalid_status
    render json: { error: 'Invalid status value' }, status: :unprocessable_content
  end

  def render_cannot_delete_self
    render json: { error: 'You cannot delete your own account' }, status: :unprocessable_content
  end

  # === Parameter Methods ===

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

    if password_provided?
      permitted.merge!(
        params.require(:team_member).permit(:password, :password_confirmation)
      )
    end

    permitted
  end

  def password_provided?
    params.dig(:team_member, :password).present?
  end

  # === Formatting Methods ===

  def format_user(user)
    {
      id: user.id.to_s,
      full_name: user.full_name,
      email: user.email,
      phone: user.phone,
      role: user.role,
      status: user.status,
      created_at: user.created_at.iso8601,
      updated_at: user.updated_at.iso8601,
      created_by_id: user.created_by_id&.to_s 
    }
  end
end
