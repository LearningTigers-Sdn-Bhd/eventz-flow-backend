# frozen_string_literal: true

module V1
  module Public
    # Public vouchers controller - accessible without authentication
    # Used for public voucher showcase pages
    class VouchersController < ApplicationController
      # Skip all authentication for public endpoints
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      # GET /v1/public/vouchers
      # Returns all active vouchers for a given event
      def index
        unless params[:event_id].present?
          return error_response(
            message: 'event_id parameter is required',
            status: :bad_request
          )
        end

        # Find event by ID (supports both numeric ID and friendly ID)
        event = Event.friendly.find(params[:event_id])

        # Get only active vouchers for this event
        @vouchers = event.vouchers.active.includes(:vendor)

        success_response(
          data: @vouchers.as_json(include: { vendor: { only: [:id, :full_name, :email, :phone] } })
        )
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Event not found', status: :not_found)
      end

      # GET /v1/public/vouchers/:id
      # Returns a single voucher by ID (only if active)
      def show
        @voucher = Voucher.includes(:vendor).find(params[:id])

        # Only return active vouchers publicly
        unless @voucher.active?
          return error_response(
            message: 'Voucher not found or not available',
            status: :not_found
          )
        end

        success_response(
          data: @voucher.as_json(include: { vendor: { only: [:id, :full_name, :email, :phone] } })
        )
      rescue ActiveRecord::RecordNotFound
        error_response(message: 'Voucher not found', status: :not_found)
      end
    end
  end
end
