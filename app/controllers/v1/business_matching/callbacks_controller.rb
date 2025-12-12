module V1
  module BusinessMatching
    class CallbacksController < ApplicationController
      # Skip CSRF check for API/Webhooks if not already handled by BaseController configuration
      skip_before_action :verify_authenticity_token, raise: false
      skip_before_action :authenticate_user!, only: [:receive]
      skip_before_action :require_verified_email!, only: [:receive]

      # POST /api/v1/business_matching/receive
      def receive
        Rails.logger.info "BusinessMatching Callback Payload: #{params.inspect}"
        event_id = params[:event_id]

        if event_id.blank?
          render json: { error: 'Missing event_id' }, status: :unprocessable_entity
          return
        end

        # Cache the output if present (handling the async workflow)
        # Check for output, data, or results keys
        raw_data = params[:output] || params[:data] || params[:results]

        if !raw_data.nil? && raw_data.is_a?(Array)
             Rails.logger.info "Caching Business Matching data for event #{event_id}: #{raw_data.size} items"
             events = raw_data.map do |event_data|
                {
                  id: event_data["id"] || event_data["_id"],
                  title: event_data["title"],
                  duration: event_data["slotDuration"],
                  location: event_data["locationLink"],
                  admin_email: event_data["adminEmail"],
                  admin_wa_number: event_data["adminWaNumber"]
                }
             end
             Rails.logger.info "Mapped Events: #{events.inspect}"
             Rails.cache.write("business_matching_events_#{event_id}", events, expires_in: 1.hour)
        else
             Rails.logger.warn "BusinessMatching Callback: No valid data array found in params[:output] or params[:data]"
        end

        # Broadcast the data to the frontend
        # We assume the entire payload is relevant.
        # Filtering standard Rails params (controller, action)
        payload = params.except(:controller, :action).as_json

        ActionCable.server.broadcast("business_matching_event_#{event_id}", payload)

        render json: { status: 'received' }, status: :ok
      end
    end
  end
end
