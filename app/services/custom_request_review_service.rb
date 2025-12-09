class CustomRequestReviewService < BaseService
  def initialize(user:, custom_request:, params: {})
    super(user, params)
    @custom_request = custom_request
  end

  def review
    authorize @custom_request, :update? # Assuming Pundit policy is in place for CustomRequest

    if @custom_request.update(review_params)
      BaseService::ServiceResult.new(success: true, data: @custom_request, status: :ok)
    else
      BaseService::ServiceResult.new(success: false, errors: @custom_request.errors.full_messages, status: :unprocessable_entity)
    end
  end

  private

  def review_params
    params.require(:custom_request).permit(:status, :resolved_price, :response_notes)
  end
end
