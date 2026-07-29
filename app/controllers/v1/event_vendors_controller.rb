module V1
  class EventVendorsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event
    before_action :set_event_vendor, only: %i[update destroy]

    # GET /v1/events/:event_id/vendors
    def index
      # Authorization is handled by event show policy
      authorize @event, :show?

      merchants = @event.event_vendors.merchants.includes(:vendor)
      exhibitors = @event.event_vendors.exhibitors.includes(
        :vendor,
        exhibitor_kits: [
          :exhibitor_team_members,
          :exhibitor_kit_items,
          :exhibitor_kit_printings,
          :custom_requests,
          :exhibitor_team_member_payments,
          { exhibitor_kit_items: { rentable_item: { image_attachment: :blob } },
            exhibitor_kit_printings: { printing_service: { image_attachment: :blob } },
            exhibitor_team_member_payments: { payment_proof_attachment: :blob } }
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
          event_vendor = EventVendor.includes(:vendor, exhibitor_kits: [:exhibitor_team_members]).find(result.data.id)
        else # Merchant
          event_vendor = EventVendor.includes(:vendor).find(result.data.id)
        end
        # NOTE: exhibitor_owner is lazy-loaded in format_event_vendor only for Exhibitor types
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

      success = ActiveRecord::Base.transaction do
        raise ActiveRecord::Rollback unless @event_vendor.update(vendor_attributes)

        if params[:vendor][:exhibitor_kit_attributes].present? && @event_vendor.is_a?(Exhibitor)
          exhibitor_kit = @event_vendor.exhibitor_kits.find(params[:vendor][:exhibitor_kit_attributes][:id])
          permitted_attrs_structure_for_kit = policy(exhibitor_kit).permitted_attributes_for_update
          strong_exhibitor_kit_params = params[:vendor][:exhibitor_kit_attributes].permit(*permitted_attrs_structure_for_kit)

          if strong_exhibitor_kit_params.present? && !exhibitor_kit.update(strong_exhibitor_kit_params)
            @event_vendor.errors.add(:exhibitor_kit, exhibitor_kit.errors.full_messages.to_sentence)
            raise ActiveRecord::Rollback
          end
        end

        true
      end

      if success && @event_vendor.errors.empty?
        @event_vendor.reload
        render json: format_event_vendor(@event_vendor), status: :ok
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
          exhibitor_kits: [
            :exhibitor_team_members,
            :exhibitor_kit_items,
            :exhibitor_kit_printings,
            :exhibitor_team_member_payments,
            { exhibitor_kit_items: { rentable_item: { image_attachment: :blob } },
              exhibitor_kit_printings: { printing_service: { image_attachment: :blob } },
              exhibitor_team_member_payments: { payment_proof_attachment: :blob } }
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
          :company_name, :company_address, :country, :pic_full_name, :pic_position,
          :pic_contact_number, :pic_email_address, :special_requirements,
          :digital_brochure_link, :qr_code_url, :is_raw_space,
          :indemnity_signed, :indemnity_document_url,
          :exhibitor_booth_price_id, :booth_quantity, :_destroy,
          { custom_fields_data: {} },
          { exhibitor_team_members_attributes: %i[id full_name email phone _destroy] }
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

      if @event.use_exhibitor_kit? && event_vendor.is_a?(Exhibitor)
        response[:exhibitor_kits] = event_vendor.exhibitor_kits.map { |kit| format_exhibitor_kit(kit) }
        response[:exhibitor_kit] = response[:exhibitor_kits].first
      end

      response
    end

    def format_exhibitor_kit(exhibitor_kit)
      # Filter items and printings for contractors
      items = exhibitor_kit.exhibitor_kit_items
      printings = exhibitor_kit.exhibitor_kit_printings

      if current_user.is_exhibition_contractor?
        # Contractors only see items where rentable_item belongs to them
        items = items.select { |item| item.rentable_item&.user_id == current_user.id }
        # Contractors only see printings if event allows contractor printing services and printing service belongs to them
        printings = if @event.allow_contractor_printing_services?
                      printings.select { |printing| printing.printing_service&.user_id == current_user.id }
                    else
                      []
                    end
      end

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
        country: exhibitor_kit.country,
        pic_full_name: exhibitor_kit.pic_full_name,
        pic_contact_number: exhibitor_kit.pic_contact_number,
        pic_email_address: exhibitor_kit.pic_email_address,
        special_requirements: exhibitor_kit.special_requirements,
        digital_brochure_link: exhibitor_kit.digital_brochure_link,
        indemnity_signed: exhibitor_kit.indemnity_signed,
        indemnity_document_url: exhibitor_kit.indemnity_document_url,
        payment_status: exhibitor_kit.payment_status,
        payment_proof_url: exhibitor_kit.exhibitor_registration_payment&.payment_proof&.attached? ? url_for(exhibitor_kit.exhibitor_registration_payment.payment_proof) : nil,
        payment_proof_status: exhibitor_kit.exhibitor_registration_payment&.status || 'pending',
        payment_note: exhibitor_kit.exhibitor_registration_payment&.note || exhibitor_kit.payment_note,
        amount_paid: exhibitor_kit.amount_paid,
        indemnity_link: exhibitor_kit.indemnity_link,
        exhibitor_booth_price_id: exhibitor_kit.exhibitor_booth_price_id,
        exhibitor_booth_price_label: exhibitor_kit.exhibitor_booth_price&.label,
        exhibitor_booth_price_zone: exhibitor_kit.exhibitor_booth_price&.zone,
        custom_fields_data: exhibitor_kit.custom_fields_data,
        ic_copy_uploaded: exhibitor_kit.ic_copy.attached?,
        exhibitor_team_members: exhibitor_kit.exhibitor_team_members.as_json(only: %i[id exhibitor_kit_id full_name email phone attendee_type attendee_id
                                                                                      created_at updated_at]),
        team_member_count: exhibitor_kit.team_member_count,
        team_member_limit: exhibitor_kit.team_member_limit,
        excess_team_member_count: exhibitor_kit.excess_team_member_count,
        paid_extra_member_count: exhibitor_kit.paid_extra_member_count,
        used_paid_extra_member_count: exhibitor_kit.used_paid_extra_member_count,
        unpaid_excess_team_member_count: exhibitor_kit.unpaid_excess_team_member_count,
        has_unpaid_excess_team_members: exhibitor_kit.has_unpaid_excess_team_members?,
        extra_team_member_fee: exhibitor_kit.extra_team_member_fee,
        extra_team_member_charges: exhibitor_kit.extra_team_member_charges,
        extra_team_member_payment_mode: extra_team_member_payment_mode(exhibitor_kit),
        exhibitor_kit_items: items.map { |item| format_exhibitor_kit_item(item) },
        exhibitor_kit_printings: printings.map { |printing| format_exhibitor_kit_printing(printing) },
        custom_requests: exhibitor_kit.custom_requests.as_json(only: %i[id description quantity status
                                                                        resolved_price response_notes created_at updated_at]),
        exhibitor_team_member_payments: exhibitor_kit.exhibitor_team_member_payments.map do |payment|
          format_exhibitor_team_member_payment(payment)
        end
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
        rentable_item: if item.rentable_item
                         {
                           id: item.rentable_item.id,
                           name: item.rentable_item.name,
                           unit_of_measure: item.rentable_item.unit_of_measure,
                           default_price: item.rentable_item.default_price,
                           image_url: item.rentable_item.image.attached? ? url_for(item.rentable_item.image) : nil
                         }
                       end
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
        printing_service: if printing.printing_service
                            {
                              id: printing.printing_service.id,
                              name: printing.printing_service.name,
                              unit_of_measure: printing.printing_service.unit_of_measure,
                              default_price: printing.printing_service.default_price,
                              image_url: printing.printing_service.image.attached? ? url_for(printing.printing_service.image) : nil
                            }
                          end
      }
    end

    def format_exhibitor_team_member_payment(payment)
      {
        id: payment.id,
        exhibitor_kit_id: payment.exhibitor_kit_id,
        payee_id: payment.payee_id,
        extra_member_count: payment.extra_member_count,
        fee_per_member: payment.fee_per_member,
        amount: payment.amount,
        status: payment.status,
        payment_source: payment.payment_source,
        payment_proof_url: payment.payment_proof.attached? ? url_for(payment.payment_proof) : nil,
        external_ref: payment.external_ref,
        note: payment.note,
        paid_at: payment.paid_at,
        created_at: payment.created_at,
        updated_at: payment.updated_at
      }
    end

    def extra_team_member_payment_mode(exhibitor_kit)
      exhibitor_kit.event.event_payment_gateway.present? ? 'payment_gateway' : 'manual_bank_in'
    end
  end
end
