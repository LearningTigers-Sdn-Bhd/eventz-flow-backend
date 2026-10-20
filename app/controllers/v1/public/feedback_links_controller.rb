module V1
  module Public
    # Resolves a short exhibitor feedback code (/feedback/:code) to the event slug and
    # signed exhibitor token the public form needs.
    class FeedbackLinksController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def show
        resolved = FeedbackLink.resolve_short(params[:code])
        return error_response(message: 'Link not found or expired', status: :not_found) unless resolved

        success_response(data: resolved)
      end
    end
  end
end
