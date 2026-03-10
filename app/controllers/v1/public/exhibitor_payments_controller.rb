# frozen_string_literal: true

require 'cgi'

module V1
  module Public
    class ExhibitorPaymentsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create_order
        event = Event.friendly.find(params[:event_slug])
        exhibitor_kit = find_exhibitor_kit!(event)

        if exhibitor_kit.paid?
          return render json: {
            success: true,
            data: {
              already_paid: true,
              exhibitor_kit_id: exhibitor_kit.id,
              payment_status: exhibitor_kit.payment_status
            }
          }, status: :ok
        end

        payment = exhibitor_kit.exhibitor_registration_payment || exhibitor_kit.build_exhibitor_registration_payment(gateway: 'razorpay')
        existing_order_id = payment.gateway_response&.dig('id') || payment.gateway_response&.dig('order_id')

        gateway = Payments::RazorpayGateway.for_event(event)

        order = if existing_order_id.present?
                  payment.gateway_response
                else
                  created_order = gateway.create_order(
                    amount_subunits: (exhibitor_kit.amount_paid.to_f * 100).round,
                    receipt: "exhibitor_kit_#{exhibitor_kit.id}",
                    notes: {
                      type: 'exhibitor_registration',
                      event_slug: event.slug,
                      exhibitor_kit_id: exhibitor_kit.id
                    }
                  )

                  payment.update!(
                    amount: exhibitor_kit.amount_paid.to_f,
                    status: 'pending',
                    gateway_response: created_order
                  )

                  created_order
                end

        callback_url = url_for(
          controller: 'v1/public/exhibitor_payments',
          action: 'callback',
          event_slug: event.slug,
          exhibitor_kit_id: exhibitor_kit.id,
          only_path: false
        )

        render json: {
          success: true,
          data: {
            exhibitor_kit_id: exhibitor_kit.id,
            key_id: gateway.key_id,
            order_id: order['id'] || order['order_id'],
            amount: order['amount'],
            currency: order['currency'] || 'MYR',
            callback_url: callback_url
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Event or exhibitor kit not found' }, status: :not_found
      rescue KeyError => e
        render json: { success: false, message: "Payment config missing: #{e.message}" }, status: :unprocessable_content
      rescue StandardError => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      def verify
        event = Event.friendly.find(params[:event_slug])
        exhibitor_kit = find_exhibitor_kit!(event)

        if exhibitor_kit.paid?
          return render json: {
            success: true,
            data: {
              already_paid: true,
              exhibitor_kit_id: exhibitor_kit.id,
              payment_status: exhibitor_kit.payment_status
            }
          }, status: :ok
        end

        order_id = params[:razorpay_order_id].to_s
        payment_id = params[:razorpay_payment_id].to_s
        signature = params[:razorpay_signature].to_s

        gateway = Payments::RazorpayGateway.for_event(event)

        unless gateway.valid_signature?(order_id: order_id, payment_id: payment_id,
                                                          signature: signature)
          return render json: { success: false, message: 'Invalid payment signature' }, status: :unprocessable_content
        end

        mark_exhibitor_kit_paid!(exhibitor_kit: exhibitor_kit, payment_id: payment_id, order_id: order_id,
                                 signature: signature)

        render json: {
          success: true,
          data: {
            exhibitor_kit_id: exhibitor_kit.id,
            payment_status: exhibitor_kit.reload.payment_status
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Event or exhibitor kit not found' }, status: :not_found
      rescue StandardError => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      def callback
        event = Event.friendly.find(params[:event_slug])
        exhibitor_kit = find_exhibitor_kit!(event)
        frontend_url = ENV.fetch('FRONTEND_FORM_URL')

        if exhibitor_kit.paid?
          return redirect_to "#{frontend_url}/exhibitor-registration?step=success&kit=#{exhibitor_kit.id}",
                             allow_other_host: true
        end

        order_id = params[:razorpay_order_id].to_s
        payment_id = params[:razorpay_payment_id].to_s
        signature = params[:razorpay_signature].to_s

        gateway = Payments::RazorpayGateway.for_event(event)

        unless gateway.valid_signature?(order_id: order_id, payment_id: payment_id,
                                                          signature: signature)
          return redirect_to "#{frontend_url}/exhibitor-registration?step=payment&error=invalid_signature&kit=#{exhibitor_kit.id}",
                             allow_other_host: true
        end

        mark_exhibitor_kit_paid!(exhibitor_kit: exhibitor_kit, payment_id: payment_id, order_id: order_id,
                                 signature: signature)
        redirect_to "#{frontend_url}/exhibitor-registration?step=success&kit=#{exhibitor_kit.id}",
                    allow_other_host: true
      rescue StandardError => e
        redirect_to "#{frontend_url}/exhibitor-registration?step=payment&error=#{CGI.escape(e.message)}",
                    allow_other_host: true
      end

      private

      def find_exhibitor_kit!(event)
        ExhibitorKit
          .joins(:event_vendor)
          .find_by!(id: params[:exhibitor_kit_id], event_vendors: { event_id: event.id, type: 'Exhibitor' })
      end

      def mark_exhibitor_kit_paid!(exhibitor_kit:, payment_id:, order_id:, signature:)
        payment = exhibitor_kit.exhibitor_registration_payment || exhibitor_kit.build_exhibitor_registration_payment(gateway: 'razorpay')

        payment.update!(
          amount: exhibitor_kit.amount_paid.to_f,
          status: 'paid',
          paid_at: Time.current,
          gateway_payment_id: payment_id,
          payment_method: 'fpx',
          gateway_response: {
            order_id: order_id,
            payment_id: payment_id,
            signature: signature
          }
        )

        exhibitor_kit.update!(payment_status: :paid)
      end
    end
  end
end
