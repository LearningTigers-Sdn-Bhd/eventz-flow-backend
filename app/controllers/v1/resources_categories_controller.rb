# app/controllers/v1/resources_categories_controller.rb
class V1::ResourcesCategoriesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :set_category, only: [:show, :update, :destroy]
  before_action :set_unscoped_category, only: [:restore, :force_destroy]

  # GET /v1/resources/categories
  def index
    authorize ResourceCategory
    filter = params.permit(:filter)[:filter]
    scope = case filter
            when 'archived'
              ResourceCategory.unscoped.where.not(deleted_at: nil)
            when 'all'
              ResourceCategory.unscoped
            else
              ResourceCategory.all
            end
    
    @pagy, @categories = pagy(scope, limit: pagination_params[:per_page])
    success_response(data: @categories, pagination: pagy_metadata(@pagy))
  end

  # GET /v1/resources/categories/:id
  def show
    authorize @category
    success_response(data: @category)
  end

  # POST /v1/resources/categories
  def create
    authorize ResourceCategory
    @category = ResourceCategory.new(category_params)
    if @category.save
      success_response(data: @category, status: :created)
    else
      error_response(errors: format_validation_errors(@category))
    end
  end

  # PATCH/PUT /v1/resources/categories/:id
  def update
    authorize @category
    if @category.update(category_params)
      success_response(data: @category)
    else
      error_response(errors: format_validation_errors(@category))
    end
  end

  # DELETE /v1/resources/categories/:id
  def destroy
    authorize @category
    @category.soft_delete
    success_response(message: 'Category soft-deleted successfully')
  end

  # POST /v1/resources/categories/:id/restore
  def restore
    authorize @category
    if @category.deleted_at.nil?
      return error_response(message: 'Resource category not found', status: :not_found)
    end
    @category.restore
    success_response(data: @category, message: 'Category restored successfully')
  end

  # DELETE /v1/resources/categories/:id/force_destroy
  def force_destroy
    authorize @category
    @category.destroy
    success_response(message: 'Category permanently deleted')
  end

  private

  def set_category
    @category = ResourceCategory.find(params[:id])
  end

  def set_unscoped_category
    @category = ResourceCategory.unscoped.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :description)
  end
end
