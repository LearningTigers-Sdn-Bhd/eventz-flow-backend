# app/controllers/v1/resources_controller.rb
class V1::ResourcesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index_public, :show_public]
  before_action :set_resource, only: [:show, :show_public, :update, :destroy, :approval]
  before_action :set_unscoped_resource, only: [:restore, :force_destroy]

  # GET /v1/resources (Authenticated - Admin/Writer)
  def index
    authorize Resource
    if current_user&.is_org_owner?
      @resources = Resource.unscoped.all
    elsif current_user&.can_write_resources?
      published_ids = Resource.unscoped.where(status: :published).pluck(:id)
      own_ids = Resource.unscoped.where(user: current_user).pluck(:id)
      all_ids = (published_ids + own_ids).uniq
      
      @resources = Resource.unscoped.where(id: all_ids)
    else
      # Fallback for authenticated members who are not writers (though policy might block them)
      @resources = Resource.where(status: :published)
    end
    success_response(data: @resources.order(published_at: :desc, created_at: :desc))
  end

  # GET /v1/resources/public (Unauthenticated)
  def index_public
    # No policy check needed for public endpoint, or use a PublicPolicy
    @resources = Resource.where(status: :published).order(published_at: :desc, created_at: :desc)
    success_response(data: @resources)
  end

  # GET /v1/resources/:id (Authenticated)
  def show
    authorize @resource
    success_response(data: @resource)
  end

  # GET /v1/resources/:id/public (Unauthenticated)
  def show_public
    # No policy check needed, but ensure we only show published unless logic dictates otherwise
    # Assuming public endpoint only shows published resources
    if @resource.published? || @resource.is_official
       success_response(data: @resource)
    else
       error_response(message: 'Resource not found or not visible', status: :not_found)
    end
  end

  # POST /v1/resources
  def create
    authorize Resource
    @resource = Resource.new(resource_params)
    @resource.user = current_user
    @resource.is_official = current_user.is_official_writer? || current_user.is_org_owner?

    if @resource.save
      success_response(data: @resource, status: :created)
    else
      error_response(errors: format_validation_errors(@resource))
    end
  end

  # PATCH/PUT /v1/resources/:id
  def update
    authorize @resource
    if @resource.update(resource_params)
      success_response(data: @resource)
    else
      error_response(errors: format_validation_errors(@resource))
    end
  end

  # DELETE /v1/resources/:id
  def destroy
    authorize @resource
    @resource.soft_delete
    success_response(message: 'Resource soft-deleted successfully')
  end

  # POST /v1/resources/:id/restore
  def restore
    authorize @resource
    if @resource.deleted_at.nil?
      return error_response(message: 'Resource not found', status: :not_found)
    end
    @resource.restore
    success_response(data: @resource, message: 'Resource restored successfully')
  end

  # DELETE /v1/resources/:id/force_destroy
  def force_destroy
    authorize @resource
    @resource.destroy
    success_response(message: 'Resource permanently deleted')
  end

  # PATCH /v1/resources/:id/approval
  def approval
    authorize @resource
    
    status = params.require(:resource).permit(:status)[:status]
    if ['published', 'draft'].include?(status)
      @resource.update(status: status, published_at: (status == 'published' ? Time.current : nil))
      success_response(data: @resource, message: "Resource status updated to '#{status}'")
    else
      error_response(message: "Invalid status provided. Must be 'published' or 'draft'.")
    end
  end

  private

  def set_resource
    @resource = Resource.find_by(slug: params[:id]) || Resource.find(params[:id])
  end

  def set_unscoped_resource
    @resource = Resource.unscoped.find_by(slug: params[:id]) || Resource.unscoped.find(params[:id])
  end

  def resource_params
    params.require(:resource).permit(
      :title, :article, :slug, :meta_description,
      :resource_topic_id, :resource_category_id, :resource_media_type_id,
      :status, :is_gated
    )
  end
end
