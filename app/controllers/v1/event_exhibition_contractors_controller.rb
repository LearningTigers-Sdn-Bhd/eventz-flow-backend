class V1::EventExhibitionContractorsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_event

  def show
    @event_exhibition_contractor = @event.event_exhibition_contractor
    if @event_exhibition_contractor.present?
      authorize @event_exhibition_contractor
      render json: format_response(@event_exhibition_contractor), status: :ok
    else
      render json: { message: "No exhibition contractor assigned to this event" }, status: :ok
    end
  end

  def create
    service = EventExhibitionContractorService.new(user: current_user, event: @event, params: params)
    result = service.create

    if result.success?
      render json: result.data, status: result.status
    else
      render json: { errors: result.errors }, status: result.status
    end
  end

  def destroy
    @event_exhibition_contractor = @event.event_exhibition_contractor
    if @event_exhibition_contractor.present?
      authorize @event_exhibition_contractor

      # Check for existing transactions before allowing deletion
      transactions = find_contractor_transactions(@event_exhibition_contractor)
      if transactions[:has_transactions]
        return render json: {
          error: 'Contractor has existing transactions',
          message: 'Cannot remove contractor because exhibitors have already made transactions for their items or services.',
          code: 'HAS_TRANSACTIONS',
          details: transactions[:details]
        }, status: :unprocessable_entity
      end

      unlink_contractor_items_from_event(@event_exhibition_contractor)
      @event.update(use_exhibitor_kit: false)
      @event_exhibition_contractor.destroy
      head :no_content
    else
      render json: { error: 'Not Found', message: 'Event exhibition contractor not found.' }, status: :not_found
    end
  end

  private

  def set_event
    @event = Event.with_deleted.friendly.find(params[:event_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
  end

  def unlink_contractor_items_from_event(contractor)
    contractor_user = contractor.exhibition_contractor_profile.user

    rentable_item_ids = contractor_user.rentable_items.pluck(:id)
    EventRentableItem.where(event: @event, rentable_item_id: rentable_item_ids).destroy_all

    printing_service_ids = contractor_user.printing_services.pluck(:id)
    EventPrintingService.where(event: @event, printing_service_id: printing_service_ids).destroy_all
  end

  def find_contractor_transactions(contractor)
    contractor_user = contractor.exhibition_contractor_profile.user

    rentable_item_ids = contractor_user.rentable_items.pluck(:id)
    printing_service_ids = contractor_user.printing_services.pluck(:id)

    # Find exhibitor kits for this event that have transactions with contractor's items
    exhibitor_kits = ExhibitorKit.joins(:event_vendor)
                                  .where(event_vendor: { event_id: @event.id })

    kit_items_count = ExhibitorKitItem.where(exhibitor_kit: exhibitor_kits, rentable_item_id: rentable_item_ids).count
    kit_printings_count = ExhibitorKitPrinting.where(exhibitor_kit: exhibitor_kits, printing_service_id: printing_service_ids).count

    has_transactions = kit_items_count > 0 || kit_printings_count > 0

    {
      has_transactions: has_transactions,
      details: {
        rentable_items_in_use: kit_items_count,
        printing_services_in_use: kit_printings_count
      }
    }
  end

  def format_response(event_exhibition_contractor)
    profile = event_exhibition_contractor.exhibition_contractor_profile
    user = profile.user

    {
      id: event_exhibition_contractor.id,
      event_id: event_exhibition_contractor.event_id,
      exhibition_contractor_profile_id: event_exhibition_contractor.exhibition_contractor_profile_id,
      created_at: event_exhibition_contractor.created_at,
      updated_at: event_exhibition_contractor.updated_at,
      exhibition_contractor_profile: {
        id: profile.id,
        user_id: profile.user_id,
        contact_person: profile.contact_person,
        contact_email: profile.contact_email,
        contact_phone: profile.contact_phone,
        standard_package_info: profile.standard_package_info,
        guidelines_pdf_url: profile.guidelines_pdf.attached? ? url_for(profile.guidelines_pdf) : nil,
        guidelines_pdf_filename: profile.guidelines_pdf.attached? ? profile.guidelines_pdf.filename.to_s : nil,
        created_at: profile.created_at,
        updated_at: profile.updated_at
      },
      contractor: {
        id: user.id,
        full_name: user.full_name,
        email: user.email,
        phone: user.phone
      }
    }
  end
end
