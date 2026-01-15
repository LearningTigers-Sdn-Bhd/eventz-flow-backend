# app/controllers/v1/resources_permissions_controller.rb
class V1::ResourcesPermissionsController < ApplicationController
  before_action :set_permission, only: [:show, :update, :destroy]

  # GET /v1/resources/permissions
  def index
    authorize ResourceWritePermission
    scope = policy_scope(ResourceWritePermission).includes(:user)
    @pagy, @permissions = pagy(scope, limit: pagination_params[:per_page])
    success_response(data: @permissions.as_json(include: :user), pagination: pagy_metadata(@pagy))
  end

  # GET /v1/resources/permissions/:id
  def show
    authorize @permission
    success_response(data: @permission)
  end

  # POST /v1/resources/permissions
  def create
    authorize ResourceWritePermission
    @permission = ResourceWritePermission.new(permission_params)

    if @permission.save
      success_response(data: @permission, status: :created)
    else
      error_response(message: 'Could not create permission', errors: format_validation_errors(@permission))
    end
  end

  # PATCH/PUT /v1/resources/permissions/:id
  def update
    authorize @permission
    if @permission.update(permission_params)
      success_response(data: @permission)
    else
      error_response(message: 'Could not update permission', errors: format_validation_errors(@permission))
    end
  end

  # DELETE /v1/resources/permissions/:id
  def destroy
    authorize @permission
    @permission.destroy
    success_response(message: 'Permission revoked successfully')
  end

  private

  def set_permission
    @permission = ResourceWritePermission.find(params[:id])
  end

  def permission_params
    params.require(:permission).permit(:user_id, :is_official, :status)
  end
end
