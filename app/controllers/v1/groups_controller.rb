module V1
  class GroupsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_group, only: [:show, :update, :destroy]
    before_action -> { authorize Group, :index? }, only: [:index]
    before_action -> { authorize Group, :create? }, only: [:create]

    # GET /v1/groups
    def index
      @groups = policy_scope(Group).includes(:group_members, :group_affiliates, :vendors)

      render json: @groups.map { |group| format_group(group) }, status: :ok
    end

    # GET /v1/groups/:id
    def show
      authorize @group

      render json: format_group(@group, include_members: true), status: :ok
    end

    # POST /v1/groups
    def create
      @group = Group.new(group_params)

      if @group.save
        # Create the first manager if manager_id is provided
        manager_id = params.dig(:group, :manager_id) || params[:manager_id]
        if manager_id.present?
          manager = User.find(manager_id)
          @group.group_members.create!(user: manager, has_manager_access: true)
        end

        render json: format_group(@group), status: :created
      else
        error_response(
          message: 'Validation failed',
          errors: format_validation_errors(@group),
          status: :unprocessable_content
        )
      end
    end

    # PATCH /v1/groups/:id
    def update
      authorize @group

      if @group.update(group_params)
        render json: format_group(@group), status: :ok
      else
        error_response(
          message: 'Validation failed',
          errors: format_validation_errors(@group),
          status: :unprocessable_content
        )
      end
    end

    # DELETE /v1/groups/:id
    def destroy
      authorize @group

      if @group.destroy
        head :no_content
      else
        error_response(
          message: 'Failed to delete group',
          errors: format_validation_errors(@group),
          status: :unprocessable_content
        )
      end
    end

    private

    def set_group
      @group = Group.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      error_response(message: 'Group not found', status: :not_found)
    end

    def group_params
      params.require(:group).permit(:name, :description)
    end

    def format_group(group, include_members: false)
      data = {
        id: group.id,
        name: group.name,
        description: group.description,
        created_at: group.created_at,
        updated_at: group.updated_at
      }

      if include_members
        data[:members] = group.group_members.includes(:user).map do |member|
          {
            id: member.id,
            user_id: member.user_id,
            user: {
              id: member.user.id,
              email: member.user.email,
              full_name: member.user.full_name,
              role: member.user.role
            },
            has_manager_access: member.has_manager_access
          }
        end
      end

      # Return multiple vendors instead of single vendor
      if group.vendors.any?
        data[:vendors] = group.vendors.map do |vendor|
          {
            id: vendor.id,
            email: vendor.email,
            full_name: vendor.full_name
          }
        end
      end

      data
    end
  end
end
