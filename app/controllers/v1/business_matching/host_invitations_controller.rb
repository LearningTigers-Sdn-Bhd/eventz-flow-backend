module V1
  module BusinessMatching
    # Read-only log of host invitation emails and their delivery status, so
    # organizers can see what was sent without needing org-owner access to the
    # global email log.
    class HostInvitationsController < ApplicationController
      # GET /v1/business_matching/events/:event_id/host_invitations
      def index
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :manage_business_hosts?

        scope = EmailDelivery.for_event(event.id)
                             .where(mailer_name: 'BookingMailer', mailer_action: 'host_invitation_email')
                             .recent
        scope = scope.where(related_type: 'BusinessMatchingSession', related_id: params[:business_matching_event_id]) if params[:business_matching_event_id].present?
        scope = scope.for_status(params[:status])
        scope = scope.for_recipient(params[:recipient])

        pagy, records = pagy(scope, limit: pagination_params[:per_page] || 25)
        render json: { data: records.map { |d| serialize(d) }, pagination: pagy_metadata(pagy) }, status: :ok
      end

      private

      # last_error is deliberately omitted: it can carry provider internals.
      def serialize(delivery)
        delivery.as_json(
          only: %i[id recipient status sent_at delivered_at failed_at bounced_at complained_at
                   suppressed_at failure_reason created_at]
        ).merge('business_matching_event_id' => delivery.metadata['business_matching_event_id'])
      end
    end
  end
end
