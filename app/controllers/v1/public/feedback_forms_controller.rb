module V1
  module Public
    class FeedbackFormsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def show
        event = Event.friendly.find(params[:event_slug])
        form = event.feedback_form
        raise ActiveRecord::RecordNotFound unless form&.is_active?

        success_response(data: FeedbackFormSerializer.serialize(form))
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Feedback form not found', status: :not_found)
      end
    end
  end
end
