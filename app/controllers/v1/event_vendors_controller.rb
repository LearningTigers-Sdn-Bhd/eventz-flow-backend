module V1
  class EventVendorsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_vendor, only: [:update, :destroy]

    # GET /v1/events/:event_id/vendors
    def index
      # Authorization is handled by event show policy
      authorize @event, :show?
      
      event_vendors = @event.event_vendors.includes(:vendor)
      # Note: exhibitor_owner is lazy-loaded in format_event_vendor only for Exhibitor types

      render json: event_vendors.map { |event_vendor| format_event_vendor(event_vendor) },
             status: :ok
    end

    # POST /v1/events/:event_id/vendors
    def create
      # Build a temporary event_vendor for authorization
      event_vendor = @event.event_vendors.build
      authorize event_vendor, policy_class: EventVendorPolicy
      
      result = EventVendorService.create(event: @event, params: vendor_params, current_user: current_user)

      if result.success?
        # Reload to get associations
        event_vendor = EventVendor.includes(:vendor).find(result.data.id)
        # Note: exhibitor_owner is lazy-loaded in format_event_vendor only for Exhibitor types
        render json: format_event_vendor(event_vendor), status: :created
      else
        render json: { error: 'Validation Error', errors: result.errors },
               status: :unprocessable_content
      end
    end

    # PATCH /v1/events/:event_id/vendors/:id
    def update
      authorize @event_vendor, policy_class: EventVendorPolicy
      
      if @event_vendor.update(update_vendor_params)
        render json: format_event_vendor(@event_vendor),
        status: :ok
      else
        render json: { error: 'Validation error', errors:
      @event_vendor.errors.full_messages },
              status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:event_id/vendors/:id
    def destroy
      authorize @event_vendor, policy_class: EventVendorPolicy
      
      if @event_vendor.destroy
        head :no_content
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
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'Event vendor not found.' }, status: :not_found
    end

    def vendor_params
      params.require(:vendor).permit(:full_name, :email, :phone, 
      :password, :password_confirmation, :vendor_id, 
      :redirect_url, :poster_url, :qr_url, :exhibitor_owner_id)
    end

    def update_vendor_params
      params.require(:vendor).permit(:redirect_url, :poster_url, :qr_url)
    end

    def format_event_vendor(event_vendor)
      response = {
        id: event_vendor.id,
        event_id: event_vendor.event_id,
        vendor_id: event_vendor.vendor_id,
        type: event_vendor.type,
        redirect_url: event_vendor.redirect_url,
        poster_url: event_vendor.poster_url,
        qr_url: event_vendor.qr_url,
        created_at: event_vendor.created_at,
        updated_at: event_vendor.updated_at,
        vendor: {
          id: event_vendor.vendor.id,
          email: event_vendor.vendor.email,
          full_name: event_vendor.vendor.full_name,
          phone: event_vendor.vendor.phone,
          role: event_vendor.vendor.role,
          status: event_vendor.vendor.status
        }
      }

      # Include exhibitor_owner for Exhibitor type
      if event_vendor.is_a?(Exhibitor) && event_vendor.exhibitor_owner.present?
        response[:exhibitor_owner] = {
          id: event_vendor.exhibitor_owner.id,
          name: event_vendor.exhibitor_owner.name,
          description: event_vendor.exhibitor_owner.description,
          contact_email: event_vendor.exhibitor_owner.contact_email,
          contact_phone: event_vendor.exhibitor_owner.contact_phone
        }
      end

      response
    end
  end
end
