module V1
  class EventVendorProfilesController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_vendor

    # GET /v1/events/:event_id/vendors/:id/profile
    def show
      authorize @event_vendor, policy_class: EventVendorPolicy
      render json: @event_vendor, status: :ok
    end

    # PATCH/PUT /v1/events/:event_id/vendors/:id/profile
    def update
      authorize @event_vendor, policy_class: EventVendorPolicy
      
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

    def profile_params
      params.require(:profile).permit(:redirect_url, :poster_url)
    end
  end
end
