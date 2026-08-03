module V1
  module Public
    class ExhibitorAccessSessionsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create
        event = Event.friendly.find(params[:event_slug])
        access = PublicExhibitorAccessSession.find_by!(event: event,
          challenge_digest: PublicExhibitorAccessSession.digest(session_params[:challenge]))
        token = access.exchange_challenge!(session_params[:challenge])
        render json: { success: true, data: { session_token: token, expires_at: access.expires_at } }, status: :created
      rescue ActiveRecord::RecordNotFound, PublicExhibitorAccessSession::InvalidToken
        render json: { success: false, code: 'invalid_or_expired_challenge', message: 'Access link is invalid or expired' },
               status: :unprocessable_content
      end

      def show
        access = authenticate_access!
        render json: { success: true, data: { email: access.normalized_email, expires_at: access.expires_at } }
      end

      def destroy
        authenticate_access!.revoke!
        head :no_content
      end

      private

      def session_params
        params.permit(:challenge)
      end

      def authenticate_access!
        event = Event.friendly.find(params[:event_slug])
        token = request.authorization.to_s.delete_prefix('Bearer ').presence
        PublicExhibitorAccessSession.authenticate(event: event, token: token) ||
          raise(CustomError::Unauthorized, 'Invalid or expired exhibitor session')
      end
    end
  end
end
