module V1
  class EventVendorProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_vendor
    before_action :authorize_vendor_or_admin!

    # GET /v1/events/:event_id/vendors/:id/profile
    def show
      render json: @event_vendor, status: :ok
    end

    # PATCH/PUT /v1/events/:event_id/vendors/:id/profile
    def update
      if @event_vendor.update(profile_params)
        render json: @event_vendor, status: :ok
      else
        render json: { error: 'Validation Error', errors: @event_vendor.errors.full_messages },
               status: :unprocessable_content
      end
    end

    private

    def set_event
      # Allow accessing archived events for record-keeping
      @event = Event.with_deleted.find(params[:event_id])
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
    end

    def set_event_vendor
      @event_vendor = @event.event_vendors.find(params[:id])
      @vendor = @event_vendor.vendor
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'Event vendor not found.' }, status: :not_found
    end

    def authorize_vendor_or_admin!
      is_vendor = current_user.id == @vendor.id && current_user.vendor?
      is_admin = current_user.is_event_admin?(@event)

      unless is_vendor || is_admin
        render json: { error: 'Forbidden', message: 'Only the vendor or event admin can perform this action.' },
               status: :forbidden
      end
    end

    def profile_params
      params.require(:profile).permit(:redirect_url, :poster_url)
    end
  end
end
