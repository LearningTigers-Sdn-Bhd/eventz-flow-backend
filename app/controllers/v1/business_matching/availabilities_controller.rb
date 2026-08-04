# frozen_string_literal: true

module V1
  module BusinessMatching
    class AvailabilitiesController < ApplicationController
      # GET /v1/business_matching/sessions/:session_id/availabilities
      def index
        session = BusinessMatchingSession.find_by(id: params[:session_id])
        return render json: { error: 'Session not found' }, status: :not_found unless session

        # Only the session's single effective bucket — showing every bucket
        # combined would double up blocks on days both happen to cover.
        availabilities = BusinessMatchingAvailability.where(
          business_matching_session_id: session.id, host_user_id: session.effective_host_user_id
        )
        render json: availabilities.map { |av|
          {
            id: av.id.to_s,
            day: av.day.to_s,
            start_time: av.start_time,
            end_time: av.end_time,
            host_user_id: av.host_user_id&.to_s
          }
        }, status: :ok
      end

      # POST /v1/business_matching/sessions/:session_id/availabilities
      def create
        session = BusinessMatchingSession.find_by(id: params[:session_id])
        return render json: { error: 'Session not found' }, status: :not_found unless session

        authorize session.event, :update?

        # Default to the session's effective bucket so a save from "Manage
        # Hours" (which never passes host_user_id) writes to the same bucket
        # that's actually read back — never creating a second parallel set.
        host_user_id = params[:host_user_id].presence || session.effective_host_user_id

        ActiveRecord::Base.transaction do
          BusinessMatchingAvailability.where(business_matching_session_id: session.id, host_user_id: host_user_id).destroy_all

          availabilities_params = params[:availabilities] || []
          availabilities_params.each do |av_param|
            BusinessMatchingAvailability.create!(
              business_matching_session: session,
              host_user_id: host_user_id,
              day: Date.parse(av_param[:day]),
              start_time: av_param[:start_time],
              end_time: av_param[:end_time]
            )
          end
        end

        ActionCable.server.broadcast("business_matching_event_#{session.event_id}", { action: "availabilities_updated" })
        render json: { message: "Availabilities updated successfully" }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
      end
    end
  end
end
