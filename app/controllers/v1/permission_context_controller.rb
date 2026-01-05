# app/controllers/v1/permission_context_controller.rb
class V1::PermissionContextController < ApplicationController
  
  # GET /v1/resources/permission_context/:id
  def show
    # The :id param is the user_id
    target_user = User.find(params[:id])
    
    # We are authorizing the action of viewing this context, not a specific record.
    # The policy simply checks if the current_user is present (authenticated).
    authorize target_user, policy_class: PermissionContextPolicy

    permission = ResourceWritePermission.find_by(user_id: target_user.id)

    if permission
      response_data = {
        has_writer_permission: true,
        updated_at: permission.updated_at
      }
    else
      response_data = {
        has_writer_permission: false,
        updated_at: nil
      }
    end

    success_response(data: response_data)
  end
end
