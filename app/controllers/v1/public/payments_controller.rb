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
              status: ticket.status
            }
          }, status: :ok
        end

        unless ticket.pending? && ticket.pending_payment?
          return render json: {
            success: false,
            message: 'Ticket is not eligible for payment'
          }, status: :unprocessable_content
        end

        # For group registrations, find all sibling tickets via registered_by_email
        group_tickets = if ticket.registered_by_email.present?
                          event.tickets.where(
                            registered_by_email: ticket.registered_by_email,
                            payment_status: :pending,
                            status: :pending_payment
                          )
                        else
                          [ticket]
                        end

        payment = ticket.ticket_payment || TicketPayment.find_or_initialize_by(ticket: ticket, gateway: 'razorpay')
        existing_order_id = payment.gateway_response&.dig('id') || payment.gateway_response&.dig('order_id')

        gateway = Payments::RazorpayGateway.for_event(event)

        callback_url = url_for(
          controller: 'v1/public/payments',
          action: 'callback',
          event_slug: event.slug,
          ticket_public_id: ticket.public_id,
          only_path: false
        )

        order = if existing_order_id.present?
                  payment.gateway_response
                else
                  total_amount = group_tickets.sum { |t| t.ticket_type.current_price.to_f }
                  amount_subunits = (total_amount * 100).round
                  notes = {
                    event_slug: event.slug,
                    ticket_public_id: ticket.public_id
                  }
                  notes[:registered_by_email] = ticket.registered_by_email if ticket.registered_by_email.present?

                  created_order = gateway.create_order(
                    amount_subunits: amount_subunits,
                    receipt: ticket.public_id,
                    notes: notes
                  )

                  payment.assign_attributes(
                    amount: total_amount,
                    status: 'pending',
                    gateway_response: created_order
                  )
                  payment.save!
                  created_order
                end

        render json: {
          success: true,
          data: {
            ticket_public_id: ticket.public_id,
            key_id: gateway.key_id,
            order_id: order['id'] || order['order_id'],
            amount: order['amount'],
            currency: order['currency'] || 'MYR',
            callback_url: callback_url
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Ticket not found' }, status: :not_found
      rescue KeyError => e
        render json: { success: false, message: "Payment config missing: #{e.message}" }, status: :unprocessable_content
      rescue StandardError => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      def callback
        require 'cgi'
        frontend_url = ENV.fetch('FRONTEND_FORM_URL')
        event = Event.friendly.find(params[:event_slug])
        ticket = event.tickets.find_by!(public_id: params[:ticket_public_id])

        # Get form slug from ticket's ticket type association
        form_slug = ticket.ticket_type.registration_forms.first&.slug || 'standard'

        # FPX redirects here after payment attempt
        order_id = params[:razorpay_order_id].to_s
        payment_id = params[:razorpay_payment_id].to_s
        signature = params[:razorpay_signature].to_s
        # Check if payment was already processed (webhook might have handled it)
        if ticket.paid? && ticket.purchased?
          redirect_to "#{frontend_url}/register/#{form_slug}?step=success&ticket=#{ticket.public_id}&email=#{CGI.escape(ticket.attendee_email || '')}",
                      allow_other_host: true
          return
        end

        gateway = Payments::RazorpayGateway.for_event(event)

        # Validate signature
        unless gateway.valid_signature?(
          order_id: order_id,
          payment_id: payment_id,
          signature: signature
        )
          redirect_to "#{frontend_url}/register/#{form_slug}?step=payment&error=invalid_signature&ticket=#{ticket.public_id}",
                      allow_other_host: true
          return
        end

        # Mark tickets as paid
        payment_entity = gateway.fetch_payment(payment_id)

        mark_tickets_paid!(
          ticket: ticket,
          event: event,
          payment_id: payment_id,
          order_id: order_id,
          signature: signature,
          payment_entity: payment_entity
        )

        redirect_to "#{frontend_url}/register/#{form_slug}?step=success&ticket=#{ticket.public_id}&email=#{CGI.escape(ticket.attendee_email || '')}",
                    allow_other_host: true
      rescue ActiveRecord::RecordNotFound
        # Try to get form_slug from the ticket if it was loaded, otherwise use 'standard'
        redirect_url = "#{frontend_url}/register/#{defined?(form_slug) && form_slug ? form_slug : 'standard'}?step=payment&error=not_found"
        redirect_to redirect_url, allow_other_host: true
      rescue StandardError => e
        redirect_url = "#{frontend_url}/register/#{defined?(form_slug) && form_slug ? form_slug : 'standard'}?step=payment&error=#{CGI.escape(e.message)}"
        redirect_url += "&ticket=#{ticket.public_id}" if defined?(ticket) && ticket&.public_id
        redirect_to redirect_url, allow_other_host: true
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
              already_paid: true
            }
          }, status: :ok
        end

        order_id = params[:razorpay_order_id].to_s
        payment_id = params[:razorpay_payment_id].to_s
        signature = params[:razorpay_signature].to_s

        gateway = Payments::RazorpayGateway.for_event(event)

        unless gateway.valid_signature?(
          order_id: order_id,
          payment_id: payment_id,
          signature: signature
        )
          return render json: { success: false, message: 'Invalid payment signature' }, status: :unprocessable_content
        end

        payment_entity = gateway.fetch_payment(payment_id)

        mark_tickets_paid!(
          ticket: ticket,
          event: event,
          payment_id: payment_id,
          order_id: order_id,
          signature: signature,
          payment_entity: payment_entity
        )

        render json: {
          success: true,
          data: {
            ticket_public_id: ticket.public_id,
            payment_status: ticket.reload.payment_status,
            status: ticket.reload.status
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Ticket not found' }, status: :not_found
      rescue StandardError => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      def webhook
        signature = request.headers['X-Razorpay-Signature'].to_s
        raw_payload = request.raw_post.to_s

        # Parse payload first to determine which event's gateway to use
        payload = JSON.parse(raw_payload)
        payment_entity = payload.dig('payload', 'payment', 'entity') || {}
        notes = payment_entity['notes'] || {}

        # Resolve the event to get the correct gateway credentials
        event = resolve_event_from_notes(notes)
        gateway = event ? Payments::RazorpayGateway.for_event(event) : Payments::RazorpayGateway.default

        unless gateway.valid_webhook_signature?(payload: raw_payload, signature: signature)
          return render json: { success: false, message: 'Invalid webhook signature' }, status: :unprocessable_content
        end

        payment_type = notes['type'].to_s

        if payment_type == 'exhibitor_registration'
          exhibitor_kit = ExhibitorKit.find_by(id: notes['exhibitor_kit_id'])
          return render json: { success: true }, status: :ok if exhibitor_kit.blank?

          case payload['event'].to_s
          when 'payment.captured'
            mark_exhibitor_registration_paid!(
              exhibitor_kit: exhibitor_kit,
              payment_id: payment_entity['id'].to_s,
              order_id: payment_entity['order_id'].to_s,
              signature: signature,
              gateway_response: payment_entity
            )
          when 'payment.failed'
            mark_exhibitor_registration_failed!(
              exhibitor_kit: exhibitor_kit,
              payment_id: payment_entity['id'].to_s,
              order_id: payment_entity['order_id'].to_s,
              gateway_response: payment_entity
            )
          end

          return render json: { success: true }, status: :ok
        end

        if payment_type == 'extra_team_member'
          payment_record = ExhibitorTeamMemberPayment.find_by(id: notes['payment_id'])
          return render json: { success: true }, status: :ok if payment_record.blank?

          case payload['event'].to_s
          when 'payment.captured'
            payment_record.with_lock do
              unless payment_record.verified?
                next unless extra_team_member_order_matches?(payment_record, payment_entity['order_id'].to_s)
                next unless extra_team_member_amount_matches?(payment_record)

                payment_record.update!(
                  status: :verified,
                  gateway_payment_id: payment_entity['id'].to_s,
                  payment_method: payment_entity['method'].to_s.presence,
                  gateway_response: payment_record.gateway_response.merge(
                    payment_entity,
                    'payment_id' => payment_entity['id'].to_s,
                    'order_id' => payment_entity['order_id'].to_s,
                    'webhook_event' => 'payment.captured'
                  ),
                  paid_at: Time.current,
                  payee_id: nil
                )
              end
            end
          when 'payment.failed'
            payment_record.with_lock do
              unless payment_record.verified?
                payment_record.update!(
                  status: :rejected,
                  note: 'Payment failed via Razorpay',
                  gateway_response: payment_record.gateway_response.merge(
                    'webhook_event' => 'payment.failed',
                    'failed_payment_id' => payment_entity['id'].to_s
                  )
                )
              end
            end
          end

          return render json: { success: true }, status: :ok
        end

        ticket_public_id = notes['ticket_public_id'].to_s

        return render json: { success: true }, status: :ok if ticket_public_id.blank?

        ticket = Ticket.find_by(public_id: ticket_public_id)
        return render json: { success: true }, status: :ok if ticket.blank?

        case payload['event'].to_s
        when 'payment.captured'
          registered_by_email = notes['registered_by_email'].to_s.presence
          mark_tickets_paid!(
            ticket: ticket,
            event: ticket.event,
            registered_by_email: registered_by_email,
            payment_id: payment_entity['id'].to_s,
            order_id: payment_entity['order_id'].to_s,
            signature: signature,
            payment_entity: payment_entity
          )
        when 'payment.failed'
          mark_ticket_failed!(ticket: ticket, payment_id: payment_entity['id'].to_s,
                              order_id: payment_entity['order_id'].to_s, gateway_response: payment_entity)
        end

        render json: { success: true }, status: :ok
      rescue KeyError => e
        render json: { success: false, message: "Payment config missing: #{e.message}" }, status: :unprocessable_content
      rescue JSON::ParserError
        render json: { success: false, message: 'Invalid webhook payload' }, status: :unprocessable_content
      rescue StandardError => e
        render json: { success: false, message: e.message }, status: :unprocessable_content
      end

      private

      def resolve_event_from_notes(notes)
        event_slug = notes['event_slug'].to_s.presence
        return Event.friendly.find(event_slug) if event_slug.present?

        ticket_public_id = notes['ticket_public_id'].to_s.presence
        return Ticket.find_by(public_id: ticket_public_id)&.event if ticket_public_id.present?

        nil
      rescue ActiveRecord::RecordNotFound
        nil
      end

      def extra_team_member_order_matches?(payment_record, order_id)
        stored_order_id = payment_record.gateway_response&.dig('id') || payment_record.gateway_response&.dig('order_id')
        stored_order_id.present? && stored_order_id == order_id
      end

      def extra_team_member_amount_matches?(payment_record)
        stored_amount = payment_record.gateway_response&.dig('amount')
        stored_amount.present? && stored_amount.to_i == (payment_record.amount * 100).to_i
      end

      def mark_tickets_paid!(ticket:, event:, payment_id:, order_id:, signature:, registered_by_email: nil, payment_entity: nil)
        # Collect all tickets to mark paid: the representative ticket plus any group siblings
        email = registered_by_email || ticket.registered_by_email
        tickets_to_mark = if email.present?
                            event.tickets.where(
                              registered_by_email: email,
                              payment_status: :pending,
                              status: :pending_payment
                            ).to_a
                          else
                            [ticket]
                          end
        # Always include the representative ticket in case it wasn't caught by the query
        tickets_to_mark |= [ticket]

        gateway_response = (payment_entity || {}).merge(order_id: order_id, payment_id: payment_id, signature: signature)

        Ticket.transaction do
          tickets_to_mark.each do |t|
            t.lock!
            next if t.paid? && t.purchased?

            payment_record = t.ticket_payment || TicketPayment.find_or_initialize_by(ticket: t, gateway: 'razorpay')
            payment_record.assign_attributes(
              amount: t.ticket_type.current_price.to_f,
              status: 'paid',
              paid_at: Time.current,
              gateway_payment_id: payment_id,
              payment_method: gateway_response['method'].to_s.presence,
              gateway_response: gateway_response
            )
            payment_record.save!

            t.update!(payment_status: :paid, status: :purchased)
          end
        end
      end

      def mark_ticket_failed!(ticket:, payment_id:, order_id:, gateway_response: nil)
        Ticket.transaction do
          ticket.lock!

          return if ticket.paid? && ticket.purchased?

          payment = ticket.ticket_payment || TicketPayment.find_or_initialize_by(ticket: ticket, gateway: 'razorpay')
          payment.assign_attributes(
            amount: ticket.ticket_type.current_price.to_f,
            status: 'failed',
            gateway_payment_id: payment_id,
            payment_method: gateway_response&.dig('method').to_s.presence,
            gateway_response: gateway_response.presence || {
              order_id: order_id,
              payment_id: payment_id
            }
          )
          payment.save!

          ticket.update!(payment_status: :failed, status: :pending_payment)
        end
      end

      def mark_exhibitor_registration_paid!(exhibitor_kit:, payment_id:, order_id:, signature:, gateway_response:)
        payment = exhibitor_kit.exhibitor_registration_payment || exhibitor_kit.build_exhibitor_registration_payment(gateway: 'razorpay')

        payment.update!(
          amount: exhibitor_kit.amount_paid.to_f,
          status: 'paid',
          paid_at: Time.current,
          gateway_payment_id: payment_id,
          payment_method: gateway_response&.dig('method').to_s.presence,
          gateway_response: gateway_response.presence || {
            order_id: order_id,
            payment_id: payment_id,
            signature: signature
          }
        )

        exhibitor_kit.update!(payment_status: :paid)
      end

      def mark_exhibitor_registration_failed!(exhibitor_kit:, payment_id:, order_id:, gateway_response:)
        payment = exhibitor_kit.exhibitor_registration_payment || exhibitor_kit.build_exhibitor_registration_payment(gateway: 'razorpay')

        payment.update!(
          amount: exhibitor_kit.amount_paid.to_f,
          status: 'failed',
          gateway_payment_id: payment_id,
          payment_method: gateway_response&.dig('method').to_s.presence,
          gateway_response: gateway_response.presence || {
            order_id: order_id,
            payment_id: payment_id
          }
        )

        exhibitor_kit.update!(payment_status: :unpaid)
      end
    end
  end
end
