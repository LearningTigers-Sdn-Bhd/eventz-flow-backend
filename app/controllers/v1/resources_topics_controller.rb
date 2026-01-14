# app/controllers/v1/resources_topics_controller.rb
class V1::ResourcesTopicsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:index, :show]
  before_action :set_topic, only: [:show, :update, :destroy]
  before_action :set_unscoped_topic, only: [:restore, :force_destroy]

  # GET /v1/resources/topics
  def index
    authorize ResourceTopic
    filter = params.permit(:filter)[:filter]
    base_scope = policy_scope(ResourceTopic)
    scope = case filter
            when 'archived'
              base_scope.unscoped.where.not(deleted_at: nil)
            when 'all'
              base_scope.unscoped
            else
              base_scope
            end

    @pagy, @topics = pagy(scope, limit: pagination_params[:per_page])
    success_response(data: @topics, pagination: pagy_metadata(@pagy))
  end

  # GET /v1/resources/topics/:id
  def show
    authorize @topic
    success_response(data: @topic)
  end

  # POST /v1/resources/topics
  def create
    authorize ResourceTopic
    @topic = ResourceTopic.new(topic_params)
    if @topic.save
      success_response(data: @topic, status: :created)
    else
      error_response(errors: format_validation_errors(@topic))
    end
  end

  # PATCH/PUT /v1/resources/topics/:id
  def update
    authorize @topic
    if @topic.update(topic_params)
      success_response(data: @topic)
    else
      error_response(errors: format_validation_errors(@topic))
    end
  end

  # DELETE /v1/resources/topics/:id
  def destroy
    authorize @topic
    @topic.soft_delete
    success_response(message: 'Topic soft-deleted successfully')
  end

  # POST /v1/resources/topics/:id/restore
  def restore
    authorize @topic
    if @topic.deleted_at.nil?
      return error_response(message: 'Resource topic not found', status: :not_found)
    end
    @topic.restore
    success_response(data: @topic, message: 'Topic restored successfully')
  end

  # DELETE /v1/resources/topics/:id/force_destroy
  def force_destroy
    authorize @topic
    @topic.destroy
    success_response(message: 'Topic permanently deleted')
  end

  private

  def set_topic
    @topic = ResourceTopic.find_by(slug: params[:id]) || ResourceTopic.find(params[:id])
  end

  def set_unscoped_topic
    @topic = ResourceTopic.unscoped.find_by(slug: params[:id]) || ResourceTopic.unscoped.find(params[:id])
  end

  def topic_params
    params.require(:topic).permit(:name, :description, :logo, :slug)
  end
end
