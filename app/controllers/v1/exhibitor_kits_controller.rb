class V1::ExhibitorKitsController < ApplicationController
  # Some browsers/OS send the legacy .xls MIME type for .xlsx uploads; accept both,
  # matching the existing xlsx allowlist in UploadsController::ALLOWED_CONTENT_TYPES.
  XLSX_CONTENT_TYPES = [
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel'
  ].freeze
  MAX_IMPORT_FILE_SIZE = 50.megabytes

  before_action :authenticate_user!
  before_action :set_event
  before_action :set_exhibitor_kit, only: %i[show update update_tags destroy submit_order reject_payment_proof resync_team_members ic_copy customs_declaration customs_duty_estimate indemnity_form permanently_delete force_delete]
  before_action :ensure_event_has_exhibitor_kit_enabled, only: %i[index show create update update_tags bulk_tags submit_order resync_team_members export import_template import]

  def index
    authorize @event, :show_exhibitor_kits?
    @exhibitor_kits = policy_scope(ExhibitorKit).joins(:event_vendor).where(event_vendors: { event_id: @event.id })
    render json: @exhibitor_kits
  end

  def show
    authorize @exhibitor_kit
    render json: format_exhibitor_kit(@exhibitor_kit)
  end

  # GET /v1/events/:event_id/exhibitor_kits/export?format=xlsx|csv
  # Downloads registered exhibitor kits for the event as an Excel workbook (default) or CSV.
  def export
    authorize @event, :analytics?

    if params[:format] == 'csv'
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      send_data(
        ExhibitorKitCsvService.export(@event.id),
        filename: "exhibitor-kits-#{@event.id}-#{timestamp}.csv",
        type: 'text/csv',
        disposition: 'attachment'
      )
    else
      result = ExhibitorKitExcelService.export(@event.id)
      send_file(
        result[:file_path],
        filename: File.basename(result[:file_path]),
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        disposition: 'attachment'
      )
    end
  rescue Pundit::NotAuthorizedError
    render json: { error: 'Not authorized to export exhibitor kits for this event' }, status: :forbidden
  end

  # GET /v1/events/:event_id/exhibitor_kits/import_template
  def import_template
    authorize @event, :update?

    result = ExhibitorKitImportTemplateService.export(@event.id)
    send_file(
      result[:file_path],
      filename: File.basename(result[:file_path]),
      type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      disposition: 'attachment'
    )
  end

  # POST /v1/events/:event_id/exhibitor_kits/import
  def import
    authorize @event, :update?

    file = params[:file]
    unless file.present?
      return render json: { error: 'No file provided' }, status: :unprocessable_content
    end
    unless file.respond_to?(:content_type) && XLSX_CONTENT_TYPES.include?(file.content_type)
      return render json: { error: 'File must be an .xlsx workbook' }, status: :unprocessable_content
    end
    if file.size.to_i > MAX_IMPORT_FILE_SIZE
      return render json: { error: 'File size exceeds the maximum allowed size of 50MB' }, status: :unprocessable_content
    end

    dry_run = ActiveModel::Type::Boolean.new.cast(params[:dry_run])
    force_duplicate_rows = Array(params[:force_duplicate_rows]).map(&:to_i)
    results = ExhibitorKitImportService.import(
      file, event: @event, current_user: current_user, dry_run: dry_run, force_duplicate_rows: force_duplicate_rows
    )
    total = results[:created][:count] + results[:errors][:count]

    render json: {
      total: total,
      created: results[:created],
      skipped: results[:skipped],
      errors: results[:errors]
    }, status: :ok
  rescue Pundit::NotAuthorizedError
    raise
  rescue StandardError => e
    Rails.logger.error "Exhibitor kit import error: #{e.message}"
    render json: { error: 'Import failed', errors: [e.message] }, status: :unprocessable_content
  end

  def create
    service = ExhibitorKitService.new(user: current_user, event: @event, params: params)
    result = service.create

    if result.success?
      render json: format_exhibitor_kit(result.data), status: result.status
    else
      render json: { errors: result.errors }, status: result.status
    end
  end

  def update
    service = ExhibitorKitService.new(user: current_user, event: @event, params: params)
    result = service.update(@exhibitor_kit)

    if result.success?
      render json: format_exhibitor_kit(result.data), status: result.status
    else
      render json: { errors: result.errors }, status: result.status
    end
  end

  # PATCH /v1/events/:event_id/exhibitor_kits/:id/tags
  # Records how many tags a kit has collected. Taking more than the event includes per kit
  # is allowed and counts as extra. Body: { exhibitor_kit: { tags_collected } }.
  def update_tags
    authorize @event, :update?

    attrs = params.require(:exhibitor_kit).permit(:tags_collected)
    if @exhibitor_kit.booking_cancelled?
      return render json: { errors: ["Cancelled kits can't collect tags"] }, status: :unprocessable_content
    end

    @exhibitor_kit.assign_attributes(attrs)
    stamp_tag_collection(@exhibitor_kit) if @exhibitor_kit.will_save_change_to_tags_collected?

    if @exhibitor_kit.save
      render json: format_exhibitor_kit(@exhibitor_kit.reload), status: :ok
    else
      render json: { errors: @exhibitor_kit.errors.full_messages }, status: :unprocessable_content
    end
  end

  # POST /v1/events/:event_id/exhibitor_kits/bulk_tags
  # operation=collect: fill every targeted kit up to the included tag count (kits that took
  #   extra stay as they are) and return the previous values so the caller can offer an undo.
  # operation=reset: set every targeted kit back to 0 collected (also returns `previous`).
  # operation=restore: put back the `items` ([{ id, tags_collected }]) from a collect or reset.
  # Targets are `kit_ids` (the ticked rows) or, without them, every kit matching `filters`
  # (the same params the Exhibitors table sends), so "select all matching" spans pages.
  def bulk_tags
    authorize @event, :update?

    case params[:operation]
    when 'collect' then render json: bulk_collect_tags, status: :ok
    when 'reset' then render json: bulk_reset_tags, status: :ok
    when 'restore' then render json: bulk_restore_tags, status: :ok
    else render json: { errors: ['operation must be collect, reset or restore'] }, status: :unprocessable_content
    end
  end

  def destroy
    authorize @exhibitor_kit

    @exhibitor_kit.with_lock do
      payment = @exhibitor_kit.exhibitor_registration_payment
      payment&.lock!
      unless @exhibitor_kit.unpaid? && @exhibitor_kit.booking_active?
        return render json: { error: 'Only unpaid active exhibitor kits can be cancelled' },
                      status: :unprocessable_content
      end
      if payment&.gateway_order_id.present? && payment.order_expires_at&.future?
        return render json: { error: 'Exhibitor kit has an active payment order' },
                      status: :unprocessable_content
      end

      @exhibitor_kit.update!(booking_status: :cancelled)
    end

    head :no_content
  end

  def permanently_delete
    authorize @exhibitor_kit, :destroy?

    unless @exhibitor_kit.booking_cancelled?
      return render json: { error: 'Only cancelled exhibitor kits can be permanently deleted' },
                    status: :unprocessable_content
    end

    @exhibitor_kit.destroy_with_event_vendor_cleanup!
    head :no_content
  end

  # Org-owner-only: hard-deletes a kit in any state, bypassing the cancel-first requirement
  # that #permanently_delete enforces for organizers.
  def force_delete
    authorize @exhibitor_kit, :force_destroy?

    @exhibitor_kit.destroy_with_event_vendor_cleanup!
    head :no_content
  end

  def submit_order
    authorize @exhibitor_kit, :update?

    service = ExhibitorKitSubmissionService.new(user: current_user, exhibitor_kit: @exhibitor_kit)
    result = service.call

    if result.success?
      success_response(data: result.data, message: 'Order submitted successfully', status: :created)
    else
      error_response(message: 'Failed to submit order', errors: Array(result.errors), status: result.status)
    end
  end

  def reject_payment_proof
    authorize @exhibitor_kit, :update?
    payment = @exhibitor_kit.exhibitor_registration_payment
    return render json: { error: 'No payment proof submitted' }, status: :unprocessable_content unless payment&.payment_proof&.attached?

    payment.update!(status: 'rejected', note: params[:note].to_s.strip.presence)
    render json: format_exhibitor_kit(@exhibitor_kit.reload), status: :ok
  end

  # POST /v1/events/:event_id/exhibitor_kits/:id/resync_team_members
  # Re-applies the kit's current company_name onto every team member's linked
  # ticket. Fixes tickets left stale after someone corrects a company name typo
  # post-registration, without touching ticket status/payment.
  def resync_team_members
    authorize @exhibitor_kit, :update?

    result = ExhibitorTeamMemberCompanyResyncService.new(@exhibitor_kit).call

    render json: {
      updated: result[:updated],
      unchanged: result[:unchanged],
      skipped: result[:skipped],
      failed: result[:failed]
    }, status: :ok
  end

  def ic_copy
    authorize @exhibitor_kit, :download_ic_copy?
    return render json: { error: 'IC copy not found' }, status: :not_found unless @exhibitor_kit.ic_copy.attached?

    send_data @exhibitor_kit.ic_copy.download,
              filename: @exhibitor_kit.ic_copy.filename.to_s,
              type: @exhibitor_kit.ic_copy.content_type,
              disposition: 'attachment'
  end

  def customs_declaration
    authorize @exhibitor_kit, :download_ic_copy?
    unless @exhibitor_kit.customs_declaration_form.attached?
      return render json: { error: 'Customs declaration form not found' }, status: :not_found
    end

    send_data @exhibitor_kit.customs_declaration_form.download,
              filename: @exhibitor_kit.customs_declaration_form.filename.to_s,
              type: @exhibitor_kit.customs_declaration_form.content_type,
              disposition: 'attachment'
  end

  def indemnity_form
    authorize @exhibitor_kit, :download_ic_copy?
    unless @exhibitor_kit.indemnity_form.attached?
      return render json: { error: 'Indemnity form not found' }, status: :not_found
    end

    send_data @exhibitor_kit.indemnity_form.download,
              filename: @exhibitor_kit.indemnity_form.filename.to_s,
              type: @exhibitor_kit.indemnity_form.content_type,
              disposition: 'attachment'
  end

  def customs_duty_estimate
    authorize @exhibitor_kit, :download_ic_copy?
    unless @exhibitor_kit.customs_duty_estimate.attached?
      return render json: { error: 'Customs duty estimate not found' }, status: :not_found
    end

    send_data @exhibitor_kit.customs_duty_estimate.download,
              filename: @exhibitor_kit.customs_duty_estimate.filename.to_s,
              type: @exhibitor_kit.customs_duty_estimate.content_type,
              disposition: 'attachment'
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_exhibitor_kit
    @exhibitor_kit = ExhibitorKit.joins(:event_vendor).find_by!(id: params[:id], event_vendors: { event_id: @event.id })
  end

  def ensure_event_has_exhibitor_kit_enabled
    return if @event.use_exhibitor_kit?

    render json: { error: 'Exhibitor kits are not enabled for this event' }, status: :forbidden
  end

  MAX_BULK_TAG_ITEMS = 2000

  def stamp_tag_collection(kit)
    collecting = kit.tags_collected.to_i.positive?
    kit.tags_collected_at = collecting ? Time.current : nil
    kit.tags_collected_by = collecting ? current_user : nil
  end

  def tag_targets
    if params[:kit_ids].present?
      ExhibitorKit.joins(:event_vendor)
                  .where(event_vendors: { event_id: @event.id }, id: Array(params[:kit_ids]).first(MAX_BULK_TAG_ITEMS))
    else
      ExhibitorKitListQuery.new(@event, params[:filters] || {}).scope
    end
  end

  def bulk_collect_tags
    per_kit = @event.exhibitor_tags_per_kit
    rows = tag_targets.reorder(nil).pluck(:id, :tags_collected, :booking_status, :payment_status)
    live, cancelled = rows.partition { |row| row[2] != 'cancelled' }
    changed = live.select { |row| row[1] < per_kit }

    ExhibitorKit.where(id: changed.map(&:first)).update_all(
      tags_collected: per_kit, tags_collected_at: Time.current,
      tags_collected_by_id: current_user.id, updated_at: Time.current
    )

    {
      updated: changed.size,
      already_complete: live.size - changed.size,
      skipped_cancelled: cancelled.size,
      unpaid: changed.count { |row| row[3] == 'unpaid' },
      previous: changed.map { |row| { id: row[0], tags_collected: row[1] } }
    }
  end

  def bulk_reset_tags
    rows = tag_targets.reorder(nil).pluck(:id, :tags_collected, :booking_status)
    changed = rows.select { |row| row[2] != 'cancelled' && row[1].positive? }

    ExhibitorKit.where(id: changed.map(&:first)).update_all(
      tags_collected: 0, tags_collected_at: nil, tags_collected_by_id: nil, updated_at: Time.current
    )

    { updated: changed.size, previous: changed.map { |row| { id: row[0], tags_collected: row[1] } } }
  end

  def bulk_restore_tags
    items = Array(params[:items]).first(MAX_BULK_TAG_ITEMS).map { |item| [item[:id].to_i, item[:tags_collected].to_i.clamp(0, 1000)] }
    kits = ExhibitorKit.joins(:event_vendor).where(event_vendors: { event_id: @event.id }, id: items.map(&:first)).index_by(&:id)

    restored = 0
    items.group_by(&:last).each do |value, group|
      ids = group.map(&:first).select { |id| kits[id] }
      next if ids.empty?

      ExhibitorKit.where(id: ids).update_all(
        tags_collected: value, tags_collected_at: value.positive? ? Time.current : nil,
        tags_collected_by_id: value.positive? ? current_user.id : nil, updated_at: Time.current
      )
      restored += ids.size
    end
    { restored: restored }
  end

  def format_exhibitor_kit(kit)
    # Filter items and printings for contractors
    items = kit.exhibitor_kit_items
    printings = kit.exhibitor_kit_printings

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

    voucher = batch_voucher(kit)
    kit.as_json(
      include: [
        { custom_requests: { only: %i[id description quantity status resolved_price response_notes] } }
      ]
    ).merge(
      ic_copy_uploaded: kit.ic_copy.attached?,
      customs_declaration_uploaded: kit.customs_declaration_form.attached?,
      customs_duty_estimate_uploaded: kit.customs_duty_estimate.attached?,
      indemnity_form_uploaded: kit.indemnity_form.attached?,
      booking_batch_id: kit.custom_fields_data['booking_batch_id'],
      tags_collected: kit.tags_collected,
      tags_included: kit.tags_included,
      extra_tags: kit.extra_tags,
      tags_collected_at: kit.tags_collected_at,
      tags_collected_by_name: kit.tags_collected_by&.full_name,
      payment_proof_url: kit.exhibitor_registration_payment&.payment_proof&.attached? ? url_for(kit.exhibitor_registration_payment.payment_proof) : nil,
      payment_proof_status: kit.exhibitor_registration_payment&.status || 'pending',
      payment_note: kit.exhibitor_registration_payment&.note || kit.payment_note,
      exhibitor_booth_id: kit.exhibitor_booths.first&.id,
      exhibitor_booth_price_label: kit.exhibitor_booth_price&.label,
      exhibitor_booth_price_zone: kit.exhibitor_booth_price&.zone,
      exhibitor_package_id: kit.exhibitor_package_id,
      exhibitor_package_name: kit.exhibitor_package&.name,
      exhibitor_package_inclusions: kit.exhibitor_package&.inclusions,
      exhibitor_voucher_code: voucher&.code,
      exhibitor_voucher_discount_type: voucher&.discount_type,
      exhibitor_voucher_discount_value: voucher&.discount_value,
      exhibitor_team_members: kit.exhibitor_team_members.as_json(
        only: %i[id exhibitor_kit_id full_name email phone attendee_type attendee_id created_at updated_at]
      ),
      exhibitor_kit_items: items.map { |item| format_kit_item(item) },
      exhibitor_kit_printings: printings.map { |printing| format_kit_printing(printing) }
    )
  end

  # A batch redeems its shared voucher once, tied to the batch's first kit — every
  # sibling kit in the batch still needs to show the voucher that discounted it.
  def batch_voucher(kit)
    return kit.applied_voucher if kit.applied_voucher

    batch_id = kit.custom_fields_data['booking_batch_id']
    return nil if batch_id.blank?

    sibling_ids = ExhibitorKit.joins(:event_vendor)
      .where(event_vendors: { event_id: kit.event.id })
      .where("custom_fields_data ->> 'booking_batch_id' = ?", batch_id)
      .pluck(:id)
    ExhibitorVoucher.find_by(redeemed_by_exhibitor_kit_id: sibling_ids)
  end

  def format_kit_item(item)
    item.as_json.merge(
      rentable_item: item.rentable_item ? format_rentable_item(item.rentable_item) : nil
    )
  end

  def format_kit_printing(printing)
    printing.as_json.merge(
      printing_service: printing.printing_service ? format_printing_service(printing.printing_service) : nil
    )
  end

  def format_rentable_item(item)
    item.as_json.merge(
      image_url: item.image.attached? ? url_for(item.image) : nil
    )
  end

  def format_printing_service(service)
    service.as_json.merge(
      image_url: service.image.attached? ? url_for(service.image) : nil
    )
  end
end
