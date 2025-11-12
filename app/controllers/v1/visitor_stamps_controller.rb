module V1
  class VisitorStampsController < ApplicationController
    # Public endpoint - no authentication required for scanning
    skip_before_action :authenticate_user!
    skip_before_action :require_verified_email!

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
      event_vendor = EventVendor.find_by(id: event_vendor_id)
      unless event_vendor
        return render json: { error: 'Not Found', message: 'Event vendor not found.' }, status: :not_found
      end

      # Verify visitor belongs to the same event as event_vendor
      unless visitor.event_id == event_vendor.event_id
        return render json: { error: 'Bad Request', message: 'Visitor does not belong to this event.' }, status: :bad_request
      end

      # Create or find existing stamp
      stamp = VisitorVendorStamp.find_or_initialize_by(
        visitor: visitor,
        event_vendor: event_vendor
      )

      if stamp.new_record?
        if stamp.save
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
  end
end
