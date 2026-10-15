# frozen_string_literal: true

module V1
  module Public
    class TicketPaymentProofsController < ApplicationController
      include PublicFileValidation

      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      MAX_FILE_SIZE = 10.megabytes

      # POST /v1/public/events/:event_slug/tickets/:public_id/payment_proof
      def create
        ticket = find_ticket!
        return if performed?

        file = params[:payment_proof]
        if file.blank? || !file.respond_to?(:content_type)
          return render json: { success: false, message: 'Payment proof is required' }, status: :unprocessable_content
        end

        unless allowed_file_type?(file)
          return render json: { success: false, message: 'Payment proof must be a JPEG, PNG, WebP, or PDF' },
                        status: :unprocessable_content
        end

        if file_too_large?(file, MAX_FILE_SIZE)
          return render json: { success: false, message: "Payment proof is too large (max #{MAX_FILE_SIZE / 1.megabyte}MB)" },
                        status: :unprocessable_content
        end

        # Uploaded once as a Blob so group bookings (one price/proof covering
        # N tickets, see RegistrationsController#create's group_public_ids)
        # can attach the SAME blob to every sibling's payment below instead
        # of re-reading the tempfile (which EOFs after the first #attach) or
        # storing N duplicate copies of one screenshot.
        blob = ActiveStorage::Blob.create_and_upload!(
          io: file, filename: file.original_filename, content_type: file.content_type
        )

        payment = attach_proof(ticket: ticket, blob: blob)

        sibling_public_ids = Array(params[:sibling_public_ids]).map(&:to_s) - [ticket.public_id]
        sibling_public_ids.each do |sibling_public_id|
          sibling_ticket = ticket.event.tickets.find_by(public_id: sibling_public_id)
          next unless sibling_ticket && sibling_ticket.payment_status.in?(%w[pending failed])

          attach_proof(ticket: sibling_ticket, blob: blob)
        end

        render json: {
          success: true,
          data: {
            public_id: ticket.public_id,
            payment_proof_uploaded: true,
            payment_proof_url: url_for(payment.payment_proof),
            payment_status: ticket.payment_status
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Ticket not found' }, status: :not_found
      end

      # DELETE /v1/public/events/:event_slug/tickets/:public_id/payment_proof
      def destroy
        ticket = find_ticket!
        return if performed?

        payment = ticket.ticket_payment
        if payment&.payment_proof&.attached?
          payment.payment_proof.purge_later
          payment.update!(payment_screenshot_url: nil)
        end

        render json: {
          success: true,
          data: {
            public_id: ticket.public_id,
            payment_proof_uploaded: false,
            payment_proof_url: nil,
            payment_status: ticket.payment_status
          }
        }, status: :ok
      rescue ActiveRecord::RecordNotFound
        render json: { success: false, message: 'Ticket not found' }, status: :not_found
      end

      private

      # Lookup by public_id (uuid) only — never the integer id. Refuses once
      # paid so a registrant cannot overwrite evidence the treasurer verified.
      def find_ticket!
        event = Event.friendly.find(params[:event_slug])
        ticket = event.tickets.find_by!(public_id: params[:public_id].to_s)

        unless ticket.payment_status.in?(%w[pending failed])
          render json: { success: false, message: 'Payment proof can no longer be changed for this ticket' },
                 status: :unprocessable_content
          return nil
        end

        ticket
      end

      def attach_proof(ticket:, blob:)
        payment = ticket.ticket_payment || ticket.create_ticket_payment!(
          amount: ticket.ticket_type&.current_price || 0,
          status: 'pending'
        )

        payment.payment_proof.attach(blob)
        payment.update!(
          payment_method: 'bank_transfer',
          status: 'pending',
          payment_screenshot_url: url_for(payment.payment_proof)
        )
        payment
      end
    end
  end
end
