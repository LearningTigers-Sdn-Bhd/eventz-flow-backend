# frozen_string_literal: true

module V1
  module Public
    class ExhibitorPaymentsController < ApplicationController
      ORDER_TTL = 30.minutes
      ACCEPTED_PAYMENT_STATUSES = %w[authorized captured].freeze

      before_action :authenticate_public_exhibitor!
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create_order
        kit = owned_kit!
        authorize kit, :show?, policy_class: PublicExhibitorBookingPolicy
        gateway = Payments::RazorpayGateway.for_event(@event)
        response = nil

        ExhibitorKit.transaction do
          kit.lock!
          return render_paid(kit) if kit.paid?
          ensure_payable!(kit)

          payment = kit.exhibitor_registration_payment || kit.create_exhibitor_registration_payment!(
            gateway: 'razorpay', amount: kit.price_snapshot, currency: kit.currency, status: 'pending'
          )
          payment.lock!
          if reusable_order?(payment, kit)
            response = payment.gateway_response
          else
            response = gateway.create_order(
              amount_subunits: amount_subunits(kit), receipt: "exh_#{kit.public_id.delete('-')}",
              notes: { type: 'exhibitor_registration', event_slug: @event.slug, booking_public_id: kit.public_id }
            )
            order_id = response['id'].presence || response['order_id'].presence
            raise PaymentError, 'invalid_gateway_order' if order_id.blank?
            payment.update!(amount: kit.price_snapshot, currency: kit.currency, status: 'pending',
              gateway_order_id: order_id, order_expires_at: ORDER_TTL.from_now, gateway_response: response)
          end
        end

        render json: { success: true, data: { public_id: kit.public_id, key_id: gateway.key_id,
          order_id: response['id'] || response['order_id'], amount: response['amount'], currency: kit.currency } }
      rescue ActiveRecord::RecordNotFound
        render_payment_error('booking_not_found', 'Booking not found', :not_found)
      rescue PaymentError => e
        render_payment_error(e.message, 'Booking cannot be paid', :unprocessable_content)
      rescue StandardError => e
        Rails.logger.error("Exhibitor payment order failed: #{e.class}")
        render_payment_error('payment_order_failed', 'Unable to create payment order', :unprocessable_content)
      end

      def verify
        kit = owned_kit!
        authorize kit, :show?, policy_class: PublicExhibitorBookingPolicy
        order_id = payment_params[:razorpay_order_id].to_s
        payment_id = payment_params[:razorpay_payment_id].to_s
        payment = kit.exhibitor_registration_payment
        return render_paid(kit) if kit.paid? && payment&.gateway_payment_id == payment_id

        gateway = Payments::RazorpayGateway.for_event(@event)

        unless gateway.valid_signature?(order_id: order_id, payment_id: payment_id,
                                        signature: payment_params[:razorpay_signature].to_s)
          return render_payment_error('invalid_payment_signature', 'Invalid payment signature', :unprocessable_content)
        end

        entity = gateway.fetch_payment(payment_id)
        validate_entity!(entity, order_id: order_id, payment_id: payment_id, kit: kit)
        already_paid = mark_paid!(kit, order_id: order_id, payment_id: payment_id, entity: entity)
        render json: { success: true, data: { already_paid: already_paid, public_id: kit.public_id,
          payment_status: kit.reload.payment_status } }
      rescue ActiveRecord::RecordNotFound
        render_payment_error('booking_not_found', 'Booking not found', :not_found)
      rescue ActiveRecord::RecordNotUnique
        render_payment_error('payment_already_used', 'Payment was already applied', :conflict)
      rescue PaymentError => e
        render_payment_error(e.message, 'Payment could not be verified', :unprocessable_content)
      rescue StandardError => e
        Rails.logger.error("Exhibitor payment verification failed: #{e.class}")
        render_payment_error('payment_verification_failed', 'Payment could not be verified', :unprocessable_content)
      end

      private

      PaymentError = Class.new(StandardError)

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

      def payment_params
        params.permit(:razorpay_order_id, :razorpay_payment_id, :razorpay_signature)
      end

      def reusable_order?(payment, kit)
        payment.status == 'pending' && payment.gateway_order_id.present? && payment.order_expires_at&.future? &&
          payment.amount == kit.price_snapshot && payment.currency == kit.currency &&
          payment.gateway_response.is_a?(Hash)
      end

      def validate_entity!(entity, order_id:, payment_id:, kit:)
        raise PaymentError, 'payment_id_mismatch' unless entity['id'] == payment_id
        raise PaymentError, 'payment_order_mismatch' unless entity['order_id'] == order_id
        raise PaymentError, 'payment_amount_mismatch' unless entity['amount'].to_i == amount_subunits(kit)
        raise PaymentError, 'payment_currency_mismatch' unless entity['currency'] == kit.currency
        raise PaymentError, 'payment_status_invalid' unless ACCEPTED_PAYMENT_STATUSES.include?(entity['status'])
      end

      def mark_paid!(kit, order_id:, payment_id:, entity:)
        ExhibitorKit.transaction do
          kit.lock!
          payment = kit.exhibitor_registration_payment
          raise PaymentError, 'payment_order_missing' unless payment
          payment.lock!
          return true if kit.paid? && payment.gateway_payment_id == payment_id
          ensure_payable!(kit)
          raise PaymentError, 'payment_order_mismatch' unless payment.gateway_order_id == order_id
          raise PaymentError, 'payment_order_expired' unless payment.order_expires_at&.future?
          raise PaymentError, 'payment_amount_mismatch' unless payment.amount == kit.price_snapshot
          raise PaymentError, 'payment_currency_mismatch' unless payment.currency == kit.currency

          payment.update!(status: 'paid', paid_at: Time.current, gateway_payment_id: payment_id,
            payment_method: entity['method'].presence, gateway_response: entity)
          kit.update!(payment_status: :paid, booking_status: :paid, reservation_expires_at: nil)
          false
        end
      end

      def amount_subunits(kit)
        (kit.price_snapshot * 100).round
      end

      def ensure_payable!(kit)
        if kit.booking_expired? || !kit.booking_active? ||
           (kit.reservation_expires_at.present? && kit.reservation_expires_at <= Time.current)
          raise PaymentError, 'booking_expired'
        end
        raise PaymentError, 'booking_not_payable' unless kit.unpaid?
      end

      def render_paid(kit)
        render json: { success: true, data: { already_paid: true, public_id: kit.public_id,
          payment_status: kit.payment_status } }
      end

      def render_payment_error(code, message, status)
        render json: { success: false, code: code, message: message }, status: status
      end
    end
  end
end
