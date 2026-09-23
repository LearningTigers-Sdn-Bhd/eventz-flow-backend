module V1
  module Public
    class FeedbackFormsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def show
        event = Event.friendly.find(params[:event_slug])
        form = event.feedback_form
        raise ActiveRecord::RecordNotFound unless form&.is_active?

        already_submitted = params[:ticket].present? &&
                            form.feedback_responses.joins(:ticket).exists?(tickets: { public_id: params[:ticket] })

        success_response(data: FeedbackFormSerializer.serialize(form).merge(already_submitted:))
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Feedback form not found', status: :not_found)
      end
    end
  end
end
