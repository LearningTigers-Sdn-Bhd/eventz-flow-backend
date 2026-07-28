module V1
  module Public
    class ExhibitorAccessRequestsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def status
        event = Event.friendly.find(params[:event_slug])
        email = PublicExhibitorAccessSession.normalize_email(access_request_params[:email])
        unless email.match?(URI::MailTo::EMAIL_REGEXP)
          return render json: { success: false, message: 'Enter a valid email address.' },
                        status: :unprocessable_content
        end

        existing = User.where('LOWER(email) = ?', email).exists? ||
          EventVendor.joins(:vendor).where(event: event).where('LOWER(users.email) = ?', email).exists?
        if existing
          access, challenge = PublicExhibitorAccessSession.issue_challenge!(event: event, email: email)
          EmailDelivery::AuditedDelivery.deliver_later(
            mailer_name: 'PublicExhibitorAccessMailer', mailer_action: 'access_link',
            args: [event, email, challenge], related: access
          )
        end

        data = { existing: existing }
        data[:new_registration_token] = PublicExhibitorRegistrationToken.issue(event: event, email: email) unless existing
        render json: { success: true, data: data }, status: existing ? :accepted : :ok
      end

      def create
        event = Event.friendly.find(params[:event_slug])
        email = PublicExhibitorAccessSession.normalize_email(access_request_params[:email])
        existing = email.match?(URI::MailTo::EMAIL_REGEXP) &&
          (User.where('LOWER(email) = ?', email).exists? ||
            EventVendor.joins(:vendor).where(event: event).where('LOWER(users.email) = ?', email).exists?)
        if existing
          access, challenge = PublicExhibitorAccessSession.issue_challenge!(event: event, email: email)
          EmailDelivery::AuditedDelivery.deliver_later(
            mailer_name: 'PublicExhibitorAccessMailer', mailer_action: 'access_link',
            args: [event, email, challenge], related: access
          )
        end

        render json: { success: true, message: 'If that email can receive mail, an access link has been sent.' },
               status: :accepted
      rescue StandardError => e
        Rails.logger.error("Public exhibitor access request failed: #{e.class}")
        render json: { success: true, message: 'If that email can receive mail, an access link has been sent.' },
               status: :accepted
      end

      private

      def access_request_params
        params.permit(:email)
      end
    end
  end
end
