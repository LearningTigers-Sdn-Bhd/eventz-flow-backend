module V1
  class EventLeadsController < ApplicationController
    skip_before_action :require_verified_email!

    # GET /v1/events/:event_id/event-leads
    def index
      event = Event.find_by(id: params[:event_id])
      unless event
        return render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
      end

      unless event.use_event_leads
        return render json: { error: 'Forbidden', message: 'Event Leads feature is not enabled for this event.' }, status: :forbidden
      end

      # Authorize: Check if user can view leads for this event
      authorize event, :index?, policy_class: EventLeadPolicy

      # Get base query for leads in this event
      base_leads = EventLead
        .includes(:event_vendor, leadable: [])
        .joins("INNER JOIN event_vendors ON event_vendors.id = event_leads.event_vendor_id")
        .where(event_vendors: { event_id: event.id })

      # Apply policy scope to filter based on user role
      leads = policy_scope(base_leads, policy_scope_class: EventLeadPolicy::Scope)
        .order(created_at: :desc)

      render json: leads.map { |lead| format_lead_with_details(lead) }, status: :ok
    end

    # POST /v1/events/:event_id/event-leads
    def create
      event = Event.find_by(id: params[:event_id])
      unless event
        return render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
      end

      unless event.use_event_leads
        return render json: { error: 'Forbidden', message: 'Event Leads feature is not enabled for this event.' }, status: :forbidden
      end

      # Get public_id and event_vendor_id from request body
      public_id = params[:public_id] || params.dig(:event_lead, :public_id)
      unless public_id
        return render json: { error: 'Bad Request', message: 'public_id is required.' }, status: :bad_request
      end

      event_vendor_id = params[:event_vendor_id] || params.dig(:event_lead, :event_vendor_id)
      unless event_vendor_id
        return render json: { error: 'Bad Request', message: 'event_vendor_id is required.' }, status: :bad_request
      end

      # Find event_vendor
      event_vendor = EventVendor.includes(:vendor).find_by(id: event_vendor_id, event_id: event.id)
      unless event_vendor
        return render json: { error: 'Not Found', message: 'Event vendor not found.' }, status: :not_found
      end

      # Authorize: Only the vendor themselves (or staff) can create leads
      authorize event_vendor, :create?, policy_class: EventLeadPolicy

      # Resolve the leadable: try Visitor first, then Ticket
      leadable = Visitor.find_by(public_id: public_id, event_id: event.id) ||
                 Ticket.find_by(public_id: public_id, event_id: event.id)

      unless leadable
        return render json: { error: 'Not Found', message: 'Attendee not found. The scanned QR code does not match any attendee in this event.' }, status: :not_found
      end

      # Create or find existing lead
      lead = EventLead.find_or_initialize_by(
        leadable: leadable,
        event_vendor: event_vendor
      )

      # Set optional fields
      lead.notes = params[:notes] || params.dig(:event_lead, :notes) if lead.new_record? || params.key?(:notes) || params.dig(:event_lead, :notes)
      lead.scanned_by = current_user if lead.new_record?

      if lead.new_record?
        if lead.save
          lead.reload
          render json: format_lead(lead).merge(already_captured: false), status: :created
        else
          render json: { error: 'Validation Error', errors: lead.errors.full_messages },
                 status: :unprocessable_content
        end
      else
        # Already captured, return existing record with flag
        render json: format_lead(lead).merge(already_captured: true), status: :ok
      end
    end

    # PATCH /v1/events/:event_id/event-leads/:id
    def update
      event = Event.find_by(id: params[:event_id])
      unless event
        return render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
      end

      lead = EventLead.joins(:event_vendor)
                       .where(event_vendors: { event_id: event.id })
                       .find_by(id: params[:id])
      unless lead
        return render json: { error: 'Not Found', message: 'Event lead not found.' }, status: :not_found
      end

      # Authorize: only the vendor themselves (or staff) can update
      authorize lead.event_vendor, :create?, policy_class: EventLeadPolicy

      notes = params[:notes] || params.dig(:event_lead, :notes)
      if lead.update(notes: notes)
        render json: format_lead(lead), status: :ok
      else
        render json: { error: 'Validation Error', errors: lead.errors.full_messages },
               status: :unprocessable_content
      end
    end

    # POST /v1/event-leads/scan
    # Global ticket lead scan: resolve event from ticket and authorize by assignment.
    def scan
      public_id = params[:public_id] || params.dig(:event_lead, :public_id)
      unless public_id
        return render json: { error: 'Bad Request', message: 'public_id is required.' }, status: :bad_request
      end

      ticket = Ticket.includes(:event).find_by(public_id: public_id)
      unless ticket
        return render json: { error: 'Not Found', message: 'Attendee not found. The scanned QR code does not match any attendee ticket.' }, status: :not_found
      end

      event = ticket.event
      unless event&.use_event_leads
        return render json: { error: 'Forbidden', code: 'event_leads_disabled', message: 'Lead scan is disabled for this event.' }, status: :forbidden
      end

      event_vendor = EventVendor.includes(:vendor).find_by(event_id: event.id, vendor_id: current_user.id)
      unless event_vendor
        return render json: { error: 'Forbidden', code: 'not_authorized_for_ticket_scan', message: 'You are not authorized to scan this ticket.' }, status: :forbidden
      end

      authorize event_vendor, :create?, policy_class: EventLeadPolicy

      lead = EventLead.find_or_initialize_by(leadable: ticket, event_vendor: event_vendor)
      lead.notes = params[:notes] || params.dig(:event_lead, :notes) if lead.new_record? || params.key?(:notes) || params.dig(:event_lead, :notes)
      lead.scanned_by = current_user if lead.new_record?

      if lead.new_record?
        if lead.save
          lead.reload
          render json: format_lead(lead).merge(already_captured: false), status: :created
        else
          render json: { error: 'Validation Error', errors: lead.errors.full_messages }, status: :unprocessable_content
        end
      else
        render json: format_lead(lead).merge(already_captured: true), status: :ok
      end
    end

    # GET /v1/events/:event_id/event-leads/export
    def export
      event = Event.find_by(id: params[:event_id])
      unless event
        return render json: { error: 'Not Found', message: 'Event not found.' }, status: :not_found
      end

      unless event.use_event_leads
        return render json: { error: 'Forbidden', message: 'Event Leads feature is not enabled for this event.' }, status: :forbidden
      end

      authorize event, :index?, policy_class: EventLeadPolicy

      base_leads = EventLead
        .includes(:event_vendor, :scanned_by, leadable: [])
        .joins("INNER JOIN event_vendors ON event_vendors.id = event_leads.event_vendor_id")
        .where(event_vendors: { event_id: event.id })

      leads = policy_scope(base_leads, policy_scope_class: EventLeadPolicy::Scope)
        .order(created_at: :desc)

      result = EventLeadExcelService.export(event, leads)
      send_file(
        result[:file_path],
        filename: File.basename(result[:file_path]),
        type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        disposition: 'attachment'
      )
    end

    # GET /v1/event-leads/recent
    # Recent lead captures for current user across assigned events.
    def recent
      limit = params[:limit].to_i
      limit = 20 if limit <= 0
      limit = 100 if limit > 100

      base_leads = EventLead
        .includes(event_vendor: :event, leadable: [])
        .joins("INNER JOIN event_vendors ON event_vendors.id = event_leads.event_vendor_id")
      leads = policy_scope(base_leads, policy_scope_class: EventLeadPolicy::Scope)
        .order(created_at: :desc)
        .limit(limit)

      render json: leads.map { |lead| format_lead_with_details(lead) }, status: :ok
    end

    private

    def format_lead(lead)
      {
        id: lead.id,
        leadable_type: lead.leadable_type,
        leadable_id: lead.leadable_id,
        event_vendor_id: lead.event_vendor_id,
        notes: lead.notes,
        scanned_by_id: lead.scanned_by_id,
        created_at: lead.created_at,
        lead: format_leadable_info(lead),
        event_vendor: {
          id: lead.event_vendor.id,
          vendor_id: lead.event_vendor.vendor_id,
          event_id: lead.event_vendor.event_id,
          event_name: lead.event_vendor.event&.title
        }
      }
    end

    def format_lead_with_details(lead)
      leadable_info = format_leadable_info(lead)

      {
        id: lead.id,
        leadable_type: lead.leadable_type,
        leadable_id: lead.leadable_id,
        lead_name: leadable_info[:name],
        lead_email: leadable_info[:email],
        lead_phone: leadable_info[:phone],
        lead_public_id: leadable_info[:public_id],
        event_vendor_id: lead.event_vendor_id,
        event_id: lead.event_vendor.event_id,
        event_name: lead.event_vendor.event&.title,
        vendor_name: lead.event_vendor.vendor&.full_name,
        notes: lead.notes,
        scanned_by_id: lead.scanned_by_id,
        created_at: lead.created_at
      }
    end

    def format_leadable_info(lead)
      case lead.leadable_type
      when 'Visitor'
        visitor = lead.leadable
        { name: visitor&.full_name, email: visitor&.email, phone: visitor&.phone, public_id: visitor&.public_id }
      when 'Ticket'
        ticket = lead.leadable
        { name: ticket&.attendee_name, email: ticket&.attendee_email, phone: ticket&.attendee_phone, public_id: ticket&.public_id }
      else
        { name: nil, email: nil, phone: nil, public_id: nil }
      end
    end

    # Helper to get policy scope with event context
    def policy_scope(scope, policy_scope_class:)
      policy_scope_class.new(current_user, scope).resolve
    end
  end
end
