# frozen_string_literal: true

module V1
  module ExhibitorTeamMemberPayments
    class RazorpayController < ApplicationController
      before_action :authenticate_user!
      before_action :set_exhibitor_kit
      skip_before_action :authenticate_user!, only: :callback
      skip_before_action :require_verified_email!, only: :callback

      def create_order
        authorize build_payment, :create_order?

        event = @exhibitor_kit.event
        gateway = Payments::RazorpayGateway.for_event(event)

        payment = @exhibitor_kit.with_lock do
          existing_payment = existing_pending_gateway_payment

          unless existing_payment.present? || @exhibitor_kit.has_unpaid_excess_team_members?
            raise PaymentValidationError, 'No unpaid excess team members to pay for'
          end

          unless event.event_payment_gateway.present?
            raise PaymentValidationError, 'No payment gateway configured for this event'
          end

          payment = existing_payment || @exhibitor_kit.exhibitor_team_member_payments.new(
            status: :pending,
            payment_source: :payment_gateway,
            gateway: 'razorpay'
          )

          payment.assign_attributes(
            extra_member_count: payable_extra_member_count(payment),
            fee_per_member: @exhibitor_kit.extra_team_member_fee,
            amount: payable_amount(payment),
            gateway: 'razorpay'
          )
          payment.save!

          order = gateway.create_order(
            amount_subunits: expected_amount_subunits(payment),
            receipt: "extra_member_#{payment.id}_#{Time.current.to_i}",
            notes: {
              type: 'extra_team_member',
              event_slug: event.slug,
              exhibitor_kit_id: @exhibitor_kit.id,
              payment_id: payment.id.to_s
            }
          )

          payment.update!(gateway_response: order)
          payment
        end

        order = payment.gateway_response

        render json: {
          success: true,
          data: {
            payment_id: payment.id,
            key_id: gateway.key_id,
            order_id: order['id'],
            amount: order['amount'],
            currency: order['currency'] || 'MYR',
            callback_url: callback_url(payment)
          }
        }, status: :ok
      rescue Pundit::NotAuthorizedError
        raise
      rescue PaymentValidationError => e
        render json: { error: e.message }, status: :unprocessable_content
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      def verify
        payment = @exhibitor_kit.exhibitor_team_member_payments.find(params[:payment_id])
        authorize payment, :verify?

        payment.with_lock do
          if payment.verified?
            return render json: {
              success: true,
              data: { already_verified: true, payment_id: payment.id }
            }, status: :ok
          end

          verify_gateway_payment!(payment, payee_id: current_user.id)
        end

        render json: {
          success: true,
          data: { payment_id: payment.id, status: payment.status }
        }, status: :ok
      rescue Pundit::NotAuthorizedError
        raise
      rescue PaymentValidationError => e
        render json: { error: e.message }, status: :unprocessable_content
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Payment not found' }, status: :not_found
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      def callback
        payment = @exhibitor_kit.exhibitor_team_member_payments.find(params[:payment_id])

        payment.with_lock do
          return redirect_to success_redirect_url, allow_other_host: true if payment.verified?

          verify_gateway_payment!(payment, payee_id: @exhibitor_kit.event_vendor.vendor_id)
        end

        redirect_to success_redirect_url, allow_other_host: true
      rescue ActiveRecord::RecordNotFound
        redirect_to error_redirect_url('not_found'), allow_other_host: true
      rescue PaymentValidationError => e
        redirect_to error_redirect_url(payment_error_reason(e)), allow_other_host: true
      rescue StandardError
        redirect_to error_redirect_url('processing_failed'), allow_other_host: true
      end

      private

      def set_exhibitor_kit
        @exhibitor_kit = ExhibitorKit
                         .joins(:event_vendor)
                         .find_by!(id: params[:exhibitor_kit_id], event_vendors: { event_id: params[:event_id] })
      end

      def build_payment
        @build_payment ||= @exhibitor_kit.exhibitor_team_member_payments.new
      end

      def existing_pending_gateway_payment
        @existing_pending_gateway_payment ||= @exhibitor_kit.exhibitor_team_member_payments.find_by(
          status: :pending,
          payment_source: :payment_gateway
        )
      end

      def verify_gateway_payment!(payment, payee_id:)
        gateway = Payments::RazorpayGateway.for_event(@exhibitor_kit.event)
        order_id = params[:razorpay_order_id].to_s
        gateway_payment_id = params[:razorpay_payment_id].to_s
        signature = params[:razorpay_signature].to_s

        unless gateway.valid_signature?(order_id: order_id, payment_id: gateway_payment_id, signature: signature)
          raise PaymentValidationError, 'Invalid payment signature'
        end

        raise PaymentValidationError, 'Payment order mismatch' unless order_matches_payment?(payment, order_id)
        raise PaymentValidationError, 'Payment amount mismatch' unless amount_matches_payment?(payment)

        payment.update!(
          status: :verified,
          gateway_payment_id: gateway_payment_id,
          payment_method: 'razorpay',
          gateway_response: payment.gateway_response.merge(
            'payment_id' => gateway_payment_id,
            'order_id' => order_id,
            'signature' => signature
          ),
          paid_at: Time.current,
          payee_id: payee_id
        )
      end

      def order_matches_payment?(payment, order_id)
        stored_order_id = payment.gateway_response&.dig('id') || payment.gateway_response&.dig('order_id')
        stored_order_id.present? && stored_order_id == order_id
      end

      def amount_matches_payment?(payment)
        stored_amount = payment.gateway_response&.dig('amount')
        stored_amount.present? && stored_amount.to_i == expected_amount_subunits(payment)
      end

      def expected_amount_subunits(payment)
        (payment.amount * 100).to_i
      end

      def payable_extra_member_count(payment)
        @exhibitor_kit.unpaid_excess_team_member_count + (payment.persisted? ? payment.extra_member_count : 0)
      end

      def payable_amount(payment)
        payable_extra_member_count(payment) * @exhibitor_kit.extra_team_member_fee
      end

      def callback_url(payment)
        url_for(
          controller: 'v1/exhibitor_team_member_payments/razorpay',
          action: 'callback',
          event_id: @exhibitor_kit.event.id,
          exhibitor_kit_id: @exhibitor_kit.id,
          payment_id: payment.id,
          only_path: false
        )
      end

      def frontend_base_url
        ENV.fetch('REDIRECT_BASE_URL', 'http://localhost:3001')
      end

      def success_redirect_url
        "#{frontend_base_url}/event/#{@exhibitor_kit.event.id}/team-members?payment=success&source=extra-team-member"
      end

      def error_redirect_url(reason)
        escaped_reason = CGI.escape(reason.to_s)
        "#{frontend_base_url}/event/#{@exhibitor_kit.event.id}/team-members?payment=error&source=extra-team-member&reason=#{escaped_reason}"
      end

      def payment_error_reason(error)
        case error.message
        when 'Invalid payment signature' then 'invalid_signature'
        when 'Payment order mismatch' then 'order_mismatch'
        when 'Payment amount mismatch' then 'amount_mismatch'
        else 'processing_failed'
        end
      end

      class PaymentValidationError < StandardError; end
    end
  end
end
