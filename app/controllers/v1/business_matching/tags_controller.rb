# frozen_string_literal: true

module V1
  module BusinessMatching
    class TagsController < ApplicationController
      # GET /v1/business_matching/events/:event_id/tags
      def show
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :business_matching_events?

        render json: {
          offering_tags: event.business_matching_offering_tags || [],
          interest_tags: event.business_matching_interest_tags || []
        }, status: :ok
      rescue Pundit::NotAuthorizedError
        render json: { error: 'You are not authorized to view this resource.' }, status: :forbidden
      end

      # PUT/PATCH /v1/business_matching/events/:event_id/tags
      def update
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :manage_business_matching_tags?

        tag_params = params.permit(
          offering_tags: [], interest_tags: [],
          renamed_offering_tags: %i[from to], renamed_interest_tags: %i[from to]
        )
        update_attrs = {}
        update_attrs[:business_matching_offering_tags] = sanitize_tags(tag_params[:offering_tags]) if tag_params.key?(:offering_tags)
        update_attrs[:business_matching_interest_tags] = sanitize_tags(tag_params[:interest_tags]) if tag_params.key?(:interest_tags)

        ActiveRecord::Base.transaction do
          event.update!(update_attrs) if update_attrs.any?
          BusinessMatchingParticipant.apply_tag_renames(
            BusinessMatchingParticipant.where(event_id: event.id),
            offering_renames: tag_params[:renamed_offering_tags] || [],
            interest_renames: tag_params[:renamed_interest_tags] || []
          )
        end

        ActionCable.server.broadcast("business_matching_event_#{event.id}", { action: 'tags_updated' })
        render json: {
          offering_tags: event.business_matching_offering_tags,
          interest_tags: event.business_matching_interest_tags
        }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue Pundit::NotAuthorizedError
        render json: { error: 'You are not authorized to perform this action.' }, status: :forbidden
      end

      private

      def sanitize_tags(tags)
        Array(tags).map(&:to_s).map(&:strip).reject(&:blank?).uniq
      end
    end
  end
end
