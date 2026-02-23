# frozen_string_literal: true

module V1
  module Public
    class PaymentsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def create_order
        event = Event.friendly.find(params[:event_slug])
        ticket = event.tickets.find_by!(public_id: params[:ticket_public_id])

        if ticket.paid? && ticket.purchased?
          return render json: {
            success: true,
            data: {
              already_paid: true,
              ticket_public_id: ticket.public_id,
              payment_status: ticket.payment_status,
              status: ticket.status,
            }
          }, status: :ok
        end

        unless ticket.pending? && ticket.pending_payment?
          return render json: {
            success: false,
            message: "Ticket is not eligible for payment"
          }, status: :unprocessable_content
        end

        # For group registrations, find all sibling tickets via registered_by_email
        group_tickets = if ticket.registered_by_email.present?
                          event.tickets.where(
                            registered_by_email: ticket.registered_by_email,
                            payment_status: :pending,
                            status: :pending_payment,
                          )
                        else
                          [ticket]
                        end

        payment = ticket.ticket_payment || TicketPayment.find_or_initialize_by(ticket: ticket, gateway: "razorpay")
        existing_order_id = payment.gateway_response&.dig("id") || payment.gateway_response&.dig("order_id")

        order = if existing_order_id.present?
                  payment.gateway_response
                else
                  total_amount = group_tickets.sum { |t| t.ticket_type.current_price.to_f }
                  amount_subunits = (total_amount * 100).round
                  notes = {
                    event_slug: event.slug,
                    ticket_public_id: ticket.public_id,
                  }
                  notes[:registered_by_email] = ticket.registered_by_email if ticket.registered_by_email.present?

                  created_order = Payments::RazorpayGateway.create_order(
                    amount_subunits: amount_subunits,
                    receipt: ticket.public_id,
                    notes: notes,
                  )

                  payment.assign_attributes(
                    amount: total_amount,
                    status: "pending",
                    gateway_response: created_order,
                  )
                  payment.save!
                  created_order
                end

        render json: {
          success: true,
          data: {
            ticket_public_id: ticket.public_id,
            key_id: Payments::RazorpayGateway.key_id,
            order_id: order["id"] || order["order_id"],
            amount: order["amount"],
            currency: order["currency"] || "MYR",
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: "Ticket not found" }, status: :not_found
      rescue KeyError => e
        render json: { success: false, message: "Payment config missing: #{e.message}" }, status: :unprocessable_content
      rescue StandardError => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      def verify
        event = Event.friendly.find(params[:event_slug])
        ticket = event.tickets.find_by!(public_id: params[:ticket_public_id])

        if ticket.paid? && ticket.purchased?
          return render json: {
            success: true,
            data: {
              ticket_public_id: ticket.public_id,
              payment_status: ticket.payment_status,
              status: ticket.status,
              already_paid: true,
            },
          }, status: :ok
        end

        order_id = params[:razorpay_order_id].to_s
        payment_id = params[:razorpay_payment_id].to_s
        signature = params[:razorpay_signature].to_s

        unless Payments::RazorpayGateway.valid_signature?(
          order_id: order_id,
          payment_id: payment_id,
          signature: signature,
        )
          return render json: { success: false, message: "Invalid payment signature" }, status: :unprocessable_content
        end

        mark_tickets_paid!(
          ticket: ticket,
          event: event,
          payment_id: payment_id,
          order_id: order_id,
          signature: signature,
        )

        render json: {
          success: true,
          data: {
            ticket_public_id: ticket.public_id,
            payment_status: ticket.reload.payment_status,
            status: ticket.reload.status,
          },
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: "Ticket not found" }, status: :not_found
      rescue StandardError => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      def webhook
        signature = request.headers["X-Razorpay-Signature"].to_s
        raw_payload = request.raw_post.to_s

        unless Payments::RazorpayGateway.valid_webhook_signature?(payload: raw_payload, signature: signature)
          return render json: { success: false, message: "Invalid webhook signature" }, status: :unprocessable_content
        end

        payload = JSON.parse(raw_payload)
        payment_entity = payload.dig("payload", "payment", "entity") || {}
        notes = payment_entity["notes"] || {}
        ticket_public_id = notes["ticket_public_id"].to_s

        return render json: { success: true }, status: :ok if ticket_public_id.blank?

        ticket = Ticket.find_by(public_id: ticket_public_id)
        return render json: { success: true }, status: :ok if ticket.blank?

        case payload["event"].to_s
        when "payment.captured"
          registered_by_email = notes["registered_by_email"].to_s.presence
          mark_tickets_paid!(
            ticket: ticket,
            event: ticket.event,
            registered_by_email: registered_by_email,
            payment_id: payment_entity["id"].to_s,
            order_id: payment_entity["order_id"].to_s,
            signature: signature,
          )
        when "payment.failed"
          mark_ticket_failed!(ticket: ticket, payment_id: payment_entity["id"].to_s, order_id: payment_entity["order_id"].to_s)
        end

        render json: { success: true }, status: :ok
      rescue KeyError => e
        render json: { success: false, message: "Payment config missing: #{e.message}" }, status: :unprocessable_content
      rescue JSON::ParserError
        render json: { success: false, message: "Invalid webhook payload" }, status: :unprocessable_content
      rescue StandardError => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      private

      def mark_tickets_paid!(ticket:, event:, payment_id:, order_id:, signature:, registered_by_email: nil)
        # Collect all tickets to mark paid: the representative ticket plus any group siblings
        email = registered_by_email || ticket.registered_by_email
        tickets_to_mark = if email.present?
                            event.tickets.where(
                              registered_by_email: email,
                              payment_status: :pending,
                              status: :pending_payment,
                            ).to_a
                          else
                            [ticket]
                          end
        # Always include the representative ticket in case it wasn't caught by the query
        tickets_to_mark |= [ticket]

        gateway_response = { order_id: order_id, payment_id: payment_id, signature: signature }

        Ticket.transaction do
          tickets_to_mark.each do |t|
            t.lock!
            next if t.paid? && t.purchased?

            payment_record = t.ticket_payment || TicketPayment.find_or_initialize_by(ticket: t, gateway: "razorpay")
            payment_record.assign_attributes(
              amount: t.ticket_type.current_price.to_f,
              status: "paid",
              paid_at: Time.current,
              gateway_payment_id: payment_id,
              payment_method: "fpx",
              gateway_response: gateway_response,
            )
            payment_record.save!

            t.update!(payment_status: :paid, status: :purchased)
          end
        end
      end

      def mark_ticket_failed!(ticket:, payment_id:, order_id:)
        Ticket.transaction do
          ticket.lock!

          return if ticket.paid? && ticket.purchased?

          payment = ticket.ticket_payment || TicketPayment.find_or_initialize_by(ticket: ticket, gateway: "razorpay")
          payment.assign_attributes(
            amount: ticket.ticket_type.current_price.to_f,
            status: "failed",
            gateway_payment_id: payment_id,
            payment_method: "fpx",
            gateway_response: {
              order_id: order_id,
              payment_id: payment_id,
            },
          )
          payment.save!

          ticket.update!(payment_status: :failed, status: :pending_payment)
        end
      end
    end
  end
end
