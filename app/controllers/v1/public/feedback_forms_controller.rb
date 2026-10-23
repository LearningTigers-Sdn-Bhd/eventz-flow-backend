module V1
  module Public
    class FeedbackFormsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def show
        event = Event.friendly.find(params[:event_slug])
        exhibitor = Exhibitor.find_signed(params[:exhibitor], purpose: :feedback) if params[:exhibitor].present?
        # An exhibitor link opens the exhibitor form; everything else is the ticket form.
        form = params[:exhibitor].present? ? event.exhibitor_feedback_form : event.feedback_form
        raise ActiveRecord::RecordNotFound unless form&.is_active?
        raise ActiveRecord::RecordNotFound if params[:exhibitor].present? && exhibitor&.event_id != event.id

        already_submitted =
          if exhibitor
            form.feedback_responses.exists?(exhibitor_id: exhibitor.id)
          else
            params[:ticket].present? &&
              form.feedback_responses.joins(:ticket).exists?(tickets: { public_id: params[:ticket] })
          end

        # Lets someone who opened the form finish it even if it's closed meanwhile.
        session_token = FeedbackSession.issue(form)

        success_response(data: FeedbackFormSerializer.serialize(form).merge(already_submitted:, session_token:, company_name: exhibitor && ExhibitorCertificate.new(exhibitor).company_name))
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Feedback form not found', status: :not_found)
      end
    end
  end
end
