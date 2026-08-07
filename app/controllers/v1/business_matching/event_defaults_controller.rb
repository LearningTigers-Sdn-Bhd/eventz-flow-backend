# frozen_string_literal: true

module V1
  module BusinessMatching
    # Per-event Business Matching defaults (date range, working hours/breaks
    # template, host-editability default) — every new session created for
    # this event prefills from these instead of a hardcoded 09:00-17:00.
    class EventDefaultsController < ApplicationController
      # GET /v1/business_matching/events/:event_id/defaults
      def show
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :manage_business_matching_sessions?

        render json: serialize(event), status: :ok
      end

      # PUT/PATCH /v1/business_matching/events/:event_id/defaults
      def update
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :manage_business_matching_sessions?

        if event.update(event_defaults_params)
          render json: serialize(event), status: :ok
        else
          render json: { errors: event.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def serialize(event)
        {
          default_start_date: event.business_matching_default_start_date,
          default_end_date: event.business_matching_default_end_date,
          default_hours: event.business_matching_default_hours,
          hours_editable_default: event.business_matching_hours_editable_default,
          default_slot_duration: event.business_matching_default_slot_duration
        }
      end

      def event_defaults_params
        permitted = params.permit(
          :default_start_date, :default_end_date, :hours_editable_default, :default_slot_duration,
          default_hours: [:start_time, :end_time]
        )
        attrs = {}
        attrs[:business_matching_default_start_date] = permitted[:default_start_date] if params.key?(:default_start_date)
        attrs[:business_matching_default_end_date] = permitted[:default_end_date] if params.key?(:default_end_date)
        attrs[:business_matching_hours_editable_default] = permitted[:hours_editable_default] if params.key?(:hours_editable_default)
        attrs[:business_matching_default_slot_duration] = permitted[:default_slot_duration] if params.key?(:default_slot_duration)
        attrs[:business_matching_default_hours] = params[:default_hours].map { |b| b.permit(:start_time, :end_time).to_h } if params[:default_hours].present?
        attrs
      end
    end
  end
end
