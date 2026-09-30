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

        # Lets someone who opened the form finish it even if it's closed meanwhile.
        session_token = FeedbackSession.issue(form)

        success_response(data: FeedbackFormSerializer.serialize(form).merge(already_submitted:, session_token:))
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Feedback form not found', status: :not_found)
      end
    end
  end
end
