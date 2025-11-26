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
      params.require(:vendor).permit(
        :full_name, :email, :phone, 
        :password, :password_confirmation, :vendor_id, 
        :redirect_url, :poster_url, :qr_url,
        exhibitor_kit_attributes: [
          :id, :booth_number, :booth_type, :booth_dimensions, :side_wall_left_required,
          :side_wall_right_required, :name_on_fascia, :fascia_upgrade_required,
          :company_name, :company_address, :pic_full_name, :pic_contact_number,
          :pic_email_address, :extra_crew_count, :special_requirements,
          :digital_brochure_link, :qr_code_url, :is_raw_space, :contractor_company_name,
          :contractor_pic_name, :contractor_pic_contact, :stand_design_file_url,
          :furniture_requests, :electrical_requests, :printing_orders,
          :indemnity_signed, :indemnity_document_url, :_destroy,
          exhibitor_team_members_attributes: [:id, :full_name, :_destroy]
        ]
      )
    end

    def update_vendor_params
      params.require(:vendor).permit(
        :redirect_url, :poster_url, :qr_url,
        exhibitor_kit_attributes: [
          :id, :booth_number, :booth_type, :booth_dimensions, :side_wall_left_required,
          :side_wall_right_required, :name_on_fascia, :fascia_upgrade_required,
          :company_name, :company_address, :pic_full_name, :pic_contact_number,
          :pic_email_address, :extra_crew_count, :special_requirements,
          :digital_brochure_link, :qr_code_url, :is_raw_space, :contractor_company_name,
          :contractor_pic_name, :contractor_pic_contact, :stand_design_file_url,
          :furniture_requests, :electrical_requests, :printing_orders,
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

      if event_vendor.is_a?(Exhibitor) && event_vendor.exhibitor_kit.present?
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
        extra_crew_count: exhibitor_kit.extra_crew_count,
        special_requirements: exhibitor_kit.special_requirements,
        digital_brochure_link: exhibitor_kit.digital_brochure_link,
        contractor_company_name: exhibitor_kit.contractor_company_name,
        contractor_pic_name: exhibitor_kit.contractor_pic_name,
        contractor_pic_contact: exhibitor_kit.contractor_pic_contact,
        stand_design_file_url: exhibitor_kit.stand_design_file_url,
        furniture_requests: exhibitor_kit.furniture_requests,
        electrical_requests: exhibitor_kit.electrical_requests,
        printing_orders: exhibitor_kit.printing_orders,
        indemnity_signed: exhibitor_kit.indemnity_signed,
        indemnity_document_url: exhibitor_kit.indemnity_document_url,
        exhibitor_team_members: exhibitor_kit.exhibitor_team_members.as_json
      }
    end
  end
end
