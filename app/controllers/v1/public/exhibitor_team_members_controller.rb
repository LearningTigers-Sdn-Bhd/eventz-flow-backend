module V1
  module Public
    # No-login self-service endpoint: an exhibitor kit's public_id acts as the link's
    # secret (unguessable base58(22), see ExhibitorKit#set_public_id) so PICs can add
    # their own team members via a shared link instead of asking the organizer to do it.
    class ExhibitorTeamMembersController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!
      before_action :set_kit
      before_action :check_link_not_expired

      def show
        render json: { success: true, data: serialize(@kit) }
      end

      def update
        unless @kit.booking_active? || @kit.booking_paid?
          return render json: { success: false, message: 'This booking is no longer open for team member changes' },
            status: :forbidden
        end

        if @kit.update(exhibitor_team_members_attributes: team_members_params)
          render json: { success: true, data: serialize(@kit.reload) }
        else
          render json: { success: false, errors: format_validation_errors(@kit) }, status: :unprocessable_content
        end
      end

      private

      def set_kit
        @kit = ExhibitorKit.find_by!(public_id: params[:public_id])
      end

      # Link stays alive until a day after the event ends — no expiry column needed,
      # Event#end_date already exists. Missing end_date (not yet scheduled) never expires.
      def check_link_not_expired
        end_date = @kit.event&.end_date
        return if end_date.blank?
        return if Time.current <= end_date + 1.day

        render json: { success: false, message: 'This invite link has expired' }, status: :gone
      end

      def team_members_params
        params.require(:exhibitor_team_members).map do |member|
          member.permit(:id, :full_name, :email, :phone, :_destroy)
        end
      end

      def serialize(kit)
        {
          public_id: kit.public_id,
          company_name: kit.company_name,
          booth_number: kit.booth_number,
          event_title: kit.event.title,
          team_member_limit: kit.team_member_limit,
          extra_team_member_fee: kit.extra_team_member_fee,
          team_members: kit.exhibitor_team_members.as_json(only: %i[id full_name email phone])
        }
      end
    end
  end
end
