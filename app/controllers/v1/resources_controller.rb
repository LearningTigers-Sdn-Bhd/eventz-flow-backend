class V1::ResourcesController < ApplicationController
  include ResourceFormatter

  skip_before_action :authenticate_user!, only: [:index_public, :show_public, :increment_view]
  before_action :set_resource, only: [:show, :show_public, :update, :destroy, :approval, :duplicate, :increment_view]
  before_action :set_unscoped_resource, only: [:restore, :force_destroy]
  before_action :ensure_not_published, only: [:update, :destroy]

  # GET /v1/resources (Authenticated - Admin/Writer)
  def index
    authorize Resource
    
    if params[:status] == 'archived'
      resources_scope = Resource.unscoped.where(user: current_user).where.not(deleted_at: nil)
    else
      # Standard Index: Scope delegated to ResourcePolicy::Scope
      resources_scope = policy_scope(Resource)

      resources_scope = resources_scope.where(status: params[:status]) if params[:status].present?
    end

    @pagy, @resources = pagy(resources_scope, limit: pagination_params[:per_page])

    # Index for writers/admin managing content: No author object needed per instruction, no summary
    formatted_resources = @resources.map { |r| format_resource(r, include_article: false, include_author: false) }
    success_response(data: formatted_resources, pagination: pagy_metadata(@pagy))
  end

  # GET /v1/resources/owner (Authenticated - Org Owner Only)
  def index_owner
    authorize Resource, :index_owner?
    
    if params[:status] == 'archived'
      resources_scope = Resource.unscoped.where.not(deleted_at: nil)
    else
      resources_scope = Resource.admin_dashboard_view
      resources_scope = resources_scope.where(status: params[:status]) if params[:status].present?
    end

    @pagy, @resources = pagy(resources_scope, limit: pagination_params[:per_page])

    # Owner Index: Includes author (to see who wrote what), no summary, no article
    formatted_resources = @resources.map { |r| format_resource(r, include_article: false, include_author: true) }
    success_response(data: formatted_resources, pagination: pagy_metadata(@pagy))
  end

  # GET /v1/resources/approval_index (Authenticated - Admin Only)
  def approval_index
    authorize Resource, :approval?
    
    resources_scope = Resource.pending_review_queue
    @pagy, @resources = pagy(resources_scope, limit: pagination_params[:per_page])

    formatted_resources = @resources.map do |resource|
      format_approval_resource(resource)
    end

    success_response(data: formatted_resources, pagination: pagy_metadata(@pagy))
  end

  # GET /v1/resources/public (Unauthenticated)
  def index_public
    resources_scope = Resource.public_feed

    resources_scope = resources_scope.where(priority: params[:priority]) if params[:priority].present?
    resources_scope = resources_scope.where('priority >= ?', params[:priority_min]) if params[:priority_min].present?
    resources_scope = resources_scope.where('priority <= ?', params[:priority_max]) if params[:priority_max].present?

    # Slug filters
    if params[:topic_slug].present? && params[:topic_slug] != 'all'
      resources_scope = resources_scope.joins(:resource_topic).where(resource_topics: { slug: params[:topic_slug] })
    end

    if params[:category_slug].present?
      slugs = params[:category_slug].is_a?(String) ? params[:category_slug].split(',') : params[:category_slug]
      resources_scope = resources_scope.joins(:resource_category).where(resource_categories: { slug: slugs })
    end

    if params[:media_type_slug].present?
      slugs = params[:media_type_slug].is_a?(String) ? params[:media_type_slug].split(',') : params[:media_type_slug]
      resources_scope = resources_scope.joins(:resource_media_type).where(resource_media_types: { slug: slugs })
    end

    @pagy, @resources = pagy(resources_scope, limit: pagination_params[:per_page])
    
    # Public index: Includes author, no summary
    formatted_resources = @resources.map { |r| format_resource(r, include_article: false, include_author: true) }
    success_response(data: formatted_resources, pagination: pagy_metadata(@pagy))
  end

  # GET /v1/resources/:id (Authenticated)
  def show
    authorize @resource
    # Show: Full details including article, author
    success_response(data: format_resource(@resource, include_article: true, include_author: true))
  end

  # GET /v1/resources/:id/public (Unauthenticated)
  def show_public
    if @resource.published? || @resource.is_official
       # Fetch 3 related resources with same topic
       suggestions = Resource.public_feed
                             .where(resource_topic_id: @resource.resource_topic_id)
                             .where.not(id: @resource.id)
                             .limit(3)

       formatted_resource = format_resource(@resource, include_article: true, include_author: true)
       formatted_suggestions = suggestions.map { |r| format_resource(r, include_article: false, include_author: true) }
       
       # Merge suggestions into the main resource object
       data = formatted_resource.merge(suggestions: formatted_suggestions)

       success_response(data: data)
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
      success_response(data: format_resource(@resource, include_article: true, include_author: true), status: :created)
    else
      error_response(errors: format_validation_errors(@resource))
    end
  end

  # PATCH/PUT /v1/resources/:id
  def update
    authorize @resource
    if @resource.update(resource_params)
      success_response(data: format_resource(@resource, include_article: true, include_author: true))
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
    success_response(data: format_resource(@resource, include_article: false, include_author: false), message: 'Resource restored successfully')
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
    
    resource_params = params.fetch(:resource, {})
    status = resource_params[:status]
    rejection_reason = resource_params[:rejection_reason]

    if ['published', 'draft', 'rejected'].include?(status)
      update_params = { status: status }
      update_params[:published_at] = (status == 'published' ? Time.current : nil)
      update_params[:rejection_reason] = rejection_reason if status == 'rejected'

      if @resource.update(update_params)
        success_response(data: format_resource(@resource, include_article: true, include_author: true), message: "Resource status updated to '#{status}'")
      else
        error_response(errors: format_validation_errors(@resource))
      end
    else
      error_response(message: "Invalid status provided. Must be 'published', 'draft', or 'rejected'.")
    end
  end

  # POST /v1/resources/:id/duplicate
  def duplicate
    authorize @resource, :create?

    new_resource = @resource.dup
    new_resource.title = "Copy of #{@resource.title}"
    new_resource.status = 'draft'
    new_resource.user = current_user
    new_resource.is_official = current_user.is_official_writer? || current_user.is_org_owner?
    new_resource.published_at = nil
    new_resource.created_at = nil
    new_resource.updated_at = nil
    new_resource.deleted_at = nil
    
    # Generate unique slug
    base_slug = new_resource.title.parameterize
    new_slug = base_slug
    counter = 1
    
    while Resource.exists?(slug: new_slug)
      counter += 1
      new_slug = "#{base_slug}-#{counter}"
    end
    
    new_resource.slug = new_slug

    if new_resource.save
      success_response(data: format_resource(new_resource, include_article: true, include_author: true), status: :created)
    else
      error_response(errors: format_validation_errors(new_resource))
    end
  end

  # POST /v1/resources/:id/increment_view
  def increment_view
    # No auth required, public endpoint
    if @resource
      @resource.increment!(:view_counts)
      success_response(message: 'View count incremented')
    else
      error_response(message: 'Resource not found', status: :not_found)
    end
  end

  private

  def ensure_not_published
    if @resource.published?
      error_response(message: 'Published resources cannot be modified or deleted. Please unpublish or archive first.', status: :forbidden)
    end
  end

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
      :status, :is_gated, :priority, :rejection_reason, :header_img
    )
  end
end
