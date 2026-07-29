module V1
  module Public
    class ExhibitorPaymentProofsController < ApplicationController
      include PublicFileValidation

      MAX_FILE_SIZE = 15.megabytes

      before_action :authenticate_public_exhibitor!
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create
        kit = owned_kit!
        authorize kit, :update?, policy_class: PublicExhibitorBookingPolicy
        return render_error('Payment proof can no longer be changed after approval') if kit.paid?
        file = params[:payment_proof]
        unless file&.respond_to?(:content_type)
          return render_error('Payment proof is required')
        end
        unless allowed_file_type?(file)
          return render_error('Payment proof must be a JPEG, PNG, WebP, or PDF')
        end
        if file_too_large?(file, MAX_FILE_SIZE)
          return render_error("Payment proof is too large (max #{MAX_FILE_SIZE / 1.megabyte}MB)")
        end

        payment = kit.exhibitor_registration_payment || kit.build_exhibitor_registration_payment(
          amount: kit.price_snapshot, currency: kit.currency, status: 'pending', payment_method: 'bank_transfer'
        )
        payment.payment_proof.attach(file)
        payment.update!(status: 'submitted', payment_method: 'bank_transfer', note: nil)
        render_proof(kit, payment)
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Booking not found' }, status: :not_found
      end

      def destroy
        kit = owned_kit!
        authorize kit, :update?, policy_class: PublicExhibitorBookingPolicy
        return render_error('Payment proof can no longer be changed after approval') if kit.paid?
        payment = kit.exhibitor_registration_payment
        payment&.payment_proof&.purge_later
        payment&.update!(status: 'pending') if payment&.status.in?(%w[submitted rejected])
        render_proof(kit, payment)
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Booking not found' }, status: :not_found
      end

      private

      def pundit_user
        @public_access
      end

      def authenticate_public_exhibitor!
        @event = Event.friendly.find(params[:event_slug])
        token = request.authorization.to_s.delete_prefix('Bearer ').presence
        @public_access = PublicExhibitorAccessSession.authenticate(event: @event, token: token)
        raise CustomError::Unauthorized, 'Invalid or expired exhibitor session' unless @public_access
      end

      def owned_kit!
        PublicExhibitorBookingPolicy::Scope.new(@public_access, ExhibitorKit).resolve
          .find_by!(public_id: params[:public_id])
      end

      def render_proof(kit, payment)
        render json: { success: true, data: { public_id: kit.public_id,
          payment_status: kit.payment_status,
          payment_proof_status: payment&.status || 'pending',
          payment_proof_uploaded: payment&.payment_proof&.attached? || false,
          payment_proof_url: payment&.payment_proof&.attached? ? url_for(payment.payment_proof) : nil } }
      end

      def render_error(message)
        render json: { success: false, message: message }, status: :unprocessable_content
      end
    end
  end
end
