# app/controllers/v1/resources_media_types_controller.rb
class V1::ResourcesMediaTypesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :set_media_type, only: [:show, :update, :destroy]
  before_action :set_unscoped_media_type, only: [:restore, :force_destroy]

  # GET /v1/resources/media_types
  def index
    authorize ResourceMediaType
    filter = params.permit(:filter)[:filter]
    scope = case filter
            when 'archived'
              ResourceMediaType.unscoped.where.not(deleted_at: nil)
            when 'all'
              ResourceMediaType.unscoped
            else
              ResourceMediaType.all
            end

    @pagy, @media_types = pagy(scope, limit: pagination_params[:per_page])
    success_response(data: @media_types, pagination: pagy_metadata(@pagy))
  end

  # GET /v1/resources/media_types/:id
  def show
    authorize @media_type
    success_response(data: @media_type)
  end

  # POST /v1/resources/media_types
  def create
    authorize ResourceMediaType
    @media_type = ResourceMediaType.new(media_type_params)
    if @media_type.save
      success_response(data: @media_type, status: :created)
    else
      error_response(errors: format_validation_errors(@media_type))
    end
  end

  # PATCH/PUT /v1/resources/media_types/:id
  def update
    authorize @media_type
    if @media_type.update(media_type_params)
      success_response(data: @media_type)
    else
      error_response(errors: format_validation_errors(@media_type))
    end
  end

  # DELETE /v1/resources/media_types/:id
  def destroy
    authorize @media_type
    @media_type.soft_delete
    success_response(message: 'Media type soft-deleted successfully')
  end

  # POST /v1/resources/media_types/:id/restore
  def restore
    authorize @media_type
    if @media_type.deleted_at.nil?
      return error_response(message: 'Resource media type not found', status: :not_found)
    end
    @media_type.restore
    success_response(data: @media_type, message: 'Media type restored successfully')
  end

  # DELETE /v1/resources/media_types/:id/force_destroy
  def force_destroy
    authorize @media_type
    @media_type.destroy
    success_response(message: 'Media type permanently deleted')
  end

  private

  def set_media_type
    @media_type = ResourceMediaType.find(params[:id])
  end

  def set_unscoped_media_type
    @media_type = ResourceMediaType.unscoped.find(params[:id])
  end

  def media_type_params
    params.require(:media_type).permit(:name, :description)
  end
end
