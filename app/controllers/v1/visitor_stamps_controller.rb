module V1
  class VisitorStampsController < ApplicationController
    # Both actions require authentication
    skip_before_action :require_verified_email!

    # GET /v1/events/:event_id/visitor-stamps
    def index
      event = Event.find_by(id: params[:event_id])
      unless event
        return render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
      end

      # Authorize: Check if user can view stamps for this event
      authorize event, :index?, policy_class: VisitorVendorStampPolicy

      # Get base query for stamps in this event
      base_stamps = VisitorVendorStamp
        .includes(:visitor, event_vendor: :vendor)
        .joins(:visitor)
        .where(visitors: { event_id: event.id })

      # Apply policy scope to filter based on user role
      stamps = policy_scope(base_stamps, policy_scope_class: VisitorVendorStampPolicy::Scope)
        .order(created_at: :desc)

      render json: stamps.map { |stamp| format_stamp_with_details(stamp) }, status: :ok
    end

    # POST /v1/visitors/:public_id/stamps
    def create
      # Find visitor by public_id
      visitor = Visitor.find_by(public_id: params[:public_id])
      unless visitor
        return render json: { error: 'Not Found', message: 'Visitor not found.' }, status: :not_found
      end

      # Get event_vendor_id from request body
      event_vendor_id = params[:event_vendor_id] || params.dig(:stamp, :event_vendor_id)
      unless event_vendor_id
        return render json: { error: 'Bad Request', message: 'event_vendor_id is required.' }, status: :bad_request
      end

      # Find event_vendor
      event_vendor = EventVendor.includes(:vendor).find_by(id: event_vendor_id)
      unless event_vendor
        return render json: { error: 'Not Found', message: 'Event vendor not found.' }, status: :not_found
      end

      # Verify visitor belongs to the same event as event_vendor
      unless visitor.event_id == event_vendor.event_id
        return render json: { error: 'Bad Request', message: 'Visitor does not belong to this event.' }, status: :bad_request
      end

      # Authorize: Only the vendor themselves can create stamps
      authorize event_vendor, :create?, policy_class: VisitorVendorStampPolicy

      # Create or find existing stamp
      stamp = VisitorVendorStamp.find_or_initialize_by(
        visitor: visitor,
        event_vendor: event_vendor
      )

      if stamp.new_record?
        if stamp.save
          # Eager load associations to avoid N+1
          stamp.reload
          render json: format_stamp(stamp), status: :created
        else
          render json: { error: 'Validation Error', errors: stamp.errors.full_messages },
                 status: :unprocessable_content
        end
      else
        # Already stamped, return existing record
        render json: format_stamp(stamp), status: :ok
      end
    end

    private

    def format_stamp(stamp)
      {
        id: stamp.id,
        visitor_id: stamp.visitor_id,
        event_vendor_id: stamp.event_vendor_id,
        created_at: stamp.created_at,
        visitor: {
          id: stamp.visitor.id,
          public_id: stamp.visitor.public_id,
          full_name: stamp.visitor.full_name,
          email: stamp.visitor.email,
          phone: stamp.visitor.phone
        },
        event_vendor: {
          id: stamp.event_vendor.id,
          vendor_id: stamp.event_vendor.vendor_id,
          event_id: stamp.event_vendor.event_id
        }
      }
    end

    def format_stamp_with_details(stamp)
      {
        id: stamp.id,
        visitor_id: stamp.visitor_id,
        visitor_name: stamp.visitor.full_name,
        visitor_email: stamp.visitor.email,
        visitor_phone: stamp.visitor.phone,
        visitor_public_id: stamp.visitor.public_id,
        event_vendor_id: stamp.event_vendor_id,
        vendor_name: stamp.event_vendor.vendor.full_name,
        created_at: stamp.created_at
      }
    end

    # Helper to get policy scope with event context
    def policy_scope(scope, policy_scope_class:)
      policy_scope_class.new(current_user, scope).resolve
    end
  end
end
