module V1
  class EventVendorsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_vendor, only: [:update, :destroy]

    # GET /v1/events/:event_id/vendors
    def index
      # Authorization is handled by event show policy
      authorize @event, :show?
      
      merchants = @event.event_vendors.merchants.includes(:vendor)
      exhibitors = @event.event_vendors.exhibitors.includes(
        :vendor, 
        :exhibitor_kit, 
        exhibitor_kit: [
          :exhibitor_team_members, 
          :exhibitor_kit_items, 
          :exhibitor_kit_printings,
          :custom_requests,
          exhibitor_kit_items: { rentable_item: { image_attachment: :blob } },
          exhibitor_kit_printings: { printing_service: { image_attachment: :blob } }
        ]
      )
      event_vendors = (merchants + exhibitors).sort_by(&:id) # Combine and maintain order

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
        event_vendor = EventVendor.find(result.data.id) # Find the record
        if event_vendor.is_a?(Exhibitor)
          event_vendor = EventVendor.includes(:vendor, :exhibitor_kit, exhibitor_kit: [:exhibitor_team_members]).find(result.data.id)
        else # Merchant
          event_vendor = EventVendor.includes(:vendor).find(result.data.id)
        end
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
      
      vendor_attributes = params.require(:vendor).permit(:redirect_url, :poster_url, :qr_url)

      # Update main event_vendor attributes
      if @event_vendor.update(vendor_attributes)
        # Handle exhibitor_kit_attributes separately if present in params and if exhibitor_kit exists
        if params[:vendor][:exhibitor_kit_attributes].present? && @event_vendor.is_a?(Exhibitor) && @event_vendor.exhibitor_kit
          permitted_attrs_structure_for_kit = policy(@event_vendor.exhibitor_kit).permitted_attributes_for_update

          # Use permit on the raw exhibitor_kit_attributes to get only permitted data
          strong_exhibitor_kit_params = params[:vendor][:exhibitor_kit_attributes].permit(*permitted_attrs_structure_for_kit)
          
          # Only update if there are permitted attributes to update
          if strong_exhibitor_kit_params.present?
            if @event_vendor.exhibitor_kit.update(strong_exhibitor_kit_params)
              # All good, continue
            else
              # If exhibitor kit update fails, add its errors to event_vendor for a combined response
              @event_vendor.errors.add(:exhibitor_kit, @event_vendor.exhibitor_kit.errors.full_messages.to_sentence)
            end
          end
        end

        if @event_vendor.errors.any? # Check if exhibitor_kit errors were added
          render json: { error: 'Validation error', errors: @event_vendor.errors.full_messages },
                 status: :unprocessable_content
        else
          @event_vendor.reload # Reload to ensure all associations are fresh
          render json: format_event_vendor(@event_vendor), status: :ok
        end
      else
        render json: { error: 'Validation error', errors: @event_vendor.errors.full_messages },
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
      @event_vendor = @event.event_vendors.includes(:vendor).find(params[:id])
      if @event_vendor.is_a?(Exhibitor)
        @event_vendor = @event.event_vendors.exhibitors.includes(
          :vendor, 
          :exhibitor_kit, 
          exhibitor_kit: [
            :exhibitor_team_members,
            :exhibitor_kit_items,
            :exhibitor_kit_printings,
            exhibitor_kit_items: { rentable_item: { image_attachment: :blob } },
            exhibitor_kit_printings: { printing_service: { image_attachment: :blob } }
          ]
        ).find(params[:id])
      end
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Not Found', message: 'Event vendor not found.' }, status: :not_found
    end

    def vendor_params
      params.require(:vendor).permit(
        :full_name, :email, :phone, 
        :password, :password_confirmation, :vendor_id, 
        :redirect_url, :poster_url, :qr_url,
        exhibitor_kit_attributes: [
          :id, :booth_number, :booth_type, :booth_dimensions, :side_wall_left_required,
          :side_wall_right_required, :name_on_fascia, :fascia_upgrade_required,
          :company_name, :company_address, :pic_full_name, :pic_contact_number,
          :pic_email_address, :special_requirements,
          :digital_brochure_link, :qr_code_url, :is_raw_space,
          :indemnity_signed, :indemnity_document_url, :_destroy,
          exhibitor_team_members_attributes: [:id, :full_name, :_destroy]
        ]
      )
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

      if @event.use_exhibitor_kit? && event_vendor.is_a?(Exhibitor) && event_vendor.exhibitor_kit
        response[:exhibitor_kit] = format_exhibitor_kit(event_vendor.exhibitor_kit)
      end

      response
    end

    def format_exhibitor_kit(exhibitor_kit)
      {
        id: exhibitor_kit.id,
        event_vendor_id: exhibitor_kit.event_vendor_id,
        booth_number: exhibitor_kit.booth_number,
        booth_type: exhibitor_kit.booth_type,
        booth_dimensions: exhibitor_kit.booth_dimensions,
        side_wall_left_required: exhibitor_kit.side_wall_left_required,
        side_wall_right_required: exhibitor_kit.side_wall_right_required,
        name_on_fascia: exhibitor_kit.name_on_fascia,
        fascia_upgrade_required: exhibitor_kit.fascia_upgrade_required,
        company_name: exhibitor_kit.company_name,
        company_address: exhibitor_kit.company_address,
        pic_full_name: exhibitor_kit.pic_full_name,
        pic_contact_number: exhibitor_kit.pic_contact_number,
        pic_email_address: exhibitor_kit.pic_email_address,
        special_requirements: exhibitor_kit.special_requirements,
        digital_brochure_link: exhibitor_kit.digital_brochure_link,
        indemnity_signed: exhibitor_kit.indemnity_signed,
        indemnity_document_url: exhibitor_kit.indemnity_document_url,
        payment_status: exhibitor_kit.payment_status,
        amount_paid: exhibitor_kit.amount_paid,
        payment_note: exhibitor_kit.payment_note,
        indemnity_link: exhibitor_kit.indemnity_link,
        exhibitor_team_members: exhibitor_kit.exhibitor_team_members.as_json(only: [:id, :exhibitor_kit_id, :full_name, :created_at, :updated_at]),
        team_member_count: exhibitor_kit.team_member_count,
        team_member_limit: exhibitor_kit.team_member_limit,
        excess_team_member_count: exhibitor_kit.excess_team_member_count,
        exceeds_team_member_limit: exhibitor_kit.exceeds_team_member_limit?,
        extra_team_member_fee: exhibitor_kit.extra_team_member_fee,
        extra_team_member_charges: exhibitor_kit.extra_team_member_charges,
        exhibitor_kit_items: exhibitor_kit.exhibitor_kit_items.map { |item| format_exhibitor_kit_item(item) },
        exhibitor_kit_printings: exhibitor_kit.exhibitor_kit_printings.map { |printing| format_exhibitor_kit_printing(printing) },
        custom_requests: exhibitor_kit.custom_requests.as_json(only: [:id, :description, :quantity, :status, :resolved_price, :response_notes, :created_at, :updated_at])
      }
    end

    def format_exhibitor_kit_item(item)
      {
        id: item.id,
        exhibitor_kit_id: item.exhibitor_kit_id,
        rentable_item_id: item.rentable_item_id,
        quantity: item.quantity,
        agreed_price: item.agreed_price,
        notes: item.notes,
        rentable_item: item.rentable_item ? {
          id: item.rentable_item.id,
          name: item.rentable_item.name,
          unit_of_measure: item.rentable_item.unit_of_measure,
          default_price: item.rentable_item.default_price,
          image_url: item.rentable_item.image.attached? ? url_for(item.rentable_item.image) : nil
        } : nil
      }
    end
    
    def format_exhibitor_kit_printing(printing)
      {
        id: printing.id,
        exhibitor_kit_id: printing.exhibitor_kit_id,
        printing_service_id: printing.printing_service_id,
        quantity: printing.quantity,
        agreed_price: printing.agreed_price,
        file_reference: printing.file_reference,
        notes: printing.notes,
        printing_service: printing.printing_service ? {
          id: printing.printing_service.id,
          name: printing.printing_service.name,
          unit_of_measure: printing.printing_service.unit_of_measure,
          default_price: printing.printing_service.default_price,
          image_url: printing.printing_service.image.attached? ? url_for(printing.printing_service.image) : nil
        } : nil
      }
    end    
  end
end
