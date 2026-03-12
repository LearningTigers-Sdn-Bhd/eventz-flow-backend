module V1
  class LeadAnalyticsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event_and_authorize
    before_action :set_event_vendor_and_authorize

    # GET /v1/events/:event_id/vendors/:id/lead_count
    def count
      # Count total leads for this vendor in this event
      total_count = EventLead.where(event_vendor: @event_vendor).count

      render json: {
        event_id: @event.id,
        vendor_id: @event_vendor.vendor_id,
        event_vendor_id: @event_vendor.id,
        lead_count: total_count
      }, status: :ok
    end

    private

    def set_event_and_authorize
      @event = Event.find(params[:event_id])
      authorize @event, :show?
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
      nil
    rescue Pundit::NotAuthorizedError
      render json: { error: 'Forbidden', message: 'Not authorized to view this event.' }, status: :forbidden
      nil
    end

    def set_event_vendor_and_authorize
      return unless @event.present?

      @event_vendor = EventVendor.find_by(id: params[:id], event: @event)
      unless @event_vendor
        render json: { error: 'Not Found', message: 'Event vendor not found.' }, status: :not_found
        return
      end

      # Authorization: vendor must be assigned to event
      unless current_user.id == @event_vendor.vendor_id || current_user.is_event_admin?(@event) || current_user.is_event_team_member?(@event)
        render json: { error: 'Forbidden', message: 'Not authorized to view analytics for this vendor.' }, status: :forbidden
        return
      end
    end
  end
end
