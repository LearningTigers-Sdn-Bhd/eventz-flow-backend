module V1
  class GroupMembersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_group
    before_action :set_group_member, only: [:update, :destroy]

    # GET /v1/groups/:group_id/members
    def index
      # Authorize access to the group
      authorize @group, :update?, policy_class: GroupPolicy
      # Authorize group member access
      authorize GroupMember.new(group: @group), policy_class: GroupMemberPolicy

      @members = @group.group_members.includes(:user)

      render json: @members.map { |member| format_member(member) }, status: :ok
    end

    # POST /v1/groups/:group_id/members
    def create
      # Authorize: org_owner or group manager
      authorize GroupMember.new(group: @group), policy_class: GroupMemberPolicy

      @member = @group.group_members.build(group_member_params)

      if @member.save
        render json: format_member(@member), status: :created
      else
        error_response(
          message: 'Validation failed',
          errors: format_validation_errors(@member),
          status: :unprocessable_content
        )
      end
    end

    # PATCH /v1/groups/:group_id/members/:id
    def update
      authorize @member, policy_class: GroupMemberPolicy

      if @member.update(group_member_params)
        render json: format_member(@member), status: :ok
      else
        error_response(
          message: 'Validation failed',
          errors: format_validation_errors(@member),
          status: :unprocessable_content
        )
      end
    end

    # DELETE /v1/groups/:group_id/members/:id
    def destroy
      authorize @member, policy_class: GroupMemberPolicy

      if @member.destroy
        head :no_content
      else
        error_response(
          message: 'Failed to remove member',
          errors: format_validation_errors(@member),
          status: :unprocessable_content
        )
      end
    end

    private

    def set_group
      @group = Group.find(params[:group_id])
    rescue ActiveRecord::RecordNotFound
      error_response(message: 'Group not found', status: :not_found)
    end

    def set_group_member
      @member = @group.group_members.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      error_response(message: 'Group member not found', status: :not_found)
    end

    def group_member_params
      params.require(:group_member).permit(:user_id, :has_manager_access)
    end

    def format_member(member)
      {
        id: member.id,
        user_id: member.user_id,
        user: {
          id: member.user.id,
          email: member.user.email,
          full_name: member.user.full_name,
          role: member.user.role
        },
        has_manager_access: member.has_manager_access,
        created_at: member.created_at,
        updated_at: member.updated_at
      }
    end
  end
end
