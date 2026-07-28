module V1
  module Public
    class ExhibitorPaymentProofsController < ApplicationController
      include PublicFileValidation

      MAX_FILE_SIZE = 10.megabytes

      before_action :authenticate_public_exhibitor!
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create
        kit = owned_kit!
        authorize kit, :update?, policy_class: PublicExhibitorBookingPolicy
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

        kit.payment_proof.attach(file)
        render_proof(kit, uploaded: true)
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Booking not found' }, status: :not_found
      end

      def destroy
        kit = owned_kit!
        authorize kit, :update?, policy_class: PublicExhibitorBookingPolicy
        kit.payment_proof.purge_later if kit.payment_proof.attached?
        render_proof(kit, uploaded: false)
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

      def render_proof(kit, uploaded:)
        render json: { success: true, data: { public_id: kit.public_id,
          payment_proof_uploaded: uploaded,
          payment_proof_url: uploaded ? url_for(kit.payment_proof) : nil } }
      end

      def render_error(message)
        render json: { success: false, message: message }, status: :unprocessable_content
      end
    end
  end
end
