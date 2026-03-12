module V1
  class EventsController < ApplicationController
    # Skip default authentication for the public `show` action, but try to authenticate if a token is present.
    skip_default_authentication only: [:show]
    prepend_before_action :authenticate_user_if_token_present, only: [:show]

    # Authorize the event instance *after* it's set
    before_action :set_event, except: %i[index create]
    before_action :authorize_event,
                  except: %i[index create business_matching_events show organizer_payment_detail]

    # Special authorization for the show action, as it can be public
    before_action -> { authorize @event, :show? if @event }, only: [:show]

    # Authorize the class for index/create (Pundit best practice)
    before_action -> { authorize Event, :index? }, only: [:index]
    before_action -> { authorize Event, :create? }, only: [:create]

    # GET /v1/events
    # Query params:
    #   - archived=true: Show only archived (soft-deleted) events
    #   - full=true: Show all events including archived ones
    def index
      # FIX: The index action must use Policy_scope, which will combine
      # the user's assigned_events and staffed_events based on the Policy::Scope logic.
      @events = policy_scope(Event)

      # Apply filtering based on query parameters
      if params[:archived] == 'true'
        # Show only archived events
        @events = @events.only_deleted
      elsif params[:full] == 'true'
        # Show all events including archived
        @events = @events.with_deleted
      end
      # Default: only non-archived events (handled by default_scope)

      render json: @events, status: :ok
    end

    # GET /v1/events/:id
    def show
      # @event is set and authorized by before_actions
      render json: @event, status: :ok
    end

    # POST /v1/events
    def create
      @event = Event.new(event_params.except(:event_admin_id))

      if @event.save
        # Step 2: Assign event admin
        # If event_admin_id is provided, assign that user; otherwise assign current_user
        admin_user = if event_params[:event_admin_id].present?
                       User.find(event_params[:event_admin_id])
                     else
                       current_user
                     end

        admin_user.assigned_event_admins.create!(event: @event)

        render json: @event, status: :created
      else
        render json: @event.errors, status: :unprocessable_content
      end
    end

    # PATCH/PUT /v1/events/:id
    def update
      # Track if flag is being toggled ON
      flag_toggled_on = !@event.allow_contractor_printing_services &&
                        ActiveModel::Type::Boolean.new.cast(event_params[:allow_contractor_printing_services])

      handle_logo
      normalize_email_setting_params

      # @event is set and authorized by before_actions
      if @event.update(event_params.except(:logo, :remove_logo, :payment_receipt_email))
        # Auto-link contractor printing services if flag was toggled ON
        ContractorPrintingServiceLinker.new(event: @event).link_if_needed if flag_toggled_on

        render json: @event, status: :ok
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_content
      end
    end

    # DELETE /v1/events/:id
    def destroy
      # @event is set and authorized by before_actions
      @event.archive
      head :no_content
    end

    # DELETE /v1/events/:id/force_delete
    def force_delete
      # @event is set and authorized by before_actions
      # Force delete requires organizer/admin authorization
      @event.delete
      head :no_content
    end

    # PATCH /v1/events/:id/restore
    def restore
      # @event is set and authorized by before_actions
      # Restore requires organizer/admin authorization
      if @event.restore
        render json: @event, status: :ok
      else
        render json: { errors: @event.errors.full_messages }, status: :unprocessable_content
      end
    end

    # GET /v1/events/:id/business_matching_events
    def business_matching_events
      unless @event.use_business_matching
        return render json: { errors: 'Business matching is not enabled for this event' }, status: :bad_request
      end

      authorize @event, :business_matching_events?

      begin
        service_result = BusinessMatchingService.new(current_user).fetch_events(@event.id,
                                                                                force_refresh: params[:force_refresh] == 'true')

        if service_result.success?
          data = service_result.data

          # Data Filtering for Business Hosts
          # If user is a host but NOT an admin/organizer, filter to their assigned sessions
          if current_user.is_business_host?(@event) && !current_user.is_org_owner_or_organizer?
            assigned_bm_ids = current_user.business_host_assignments.where(event_id: @event.id).pluck(:business_matching_event_id)
            data = data.select { |session| assigned_bm_ids.include?(session[:id].to_s) }
          end

          render json: data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      rescue StandardError => e
        # DEBUGGING: Render the actual error message
        render json: { error: e.message, backtrace: e.backtrace.first(5) }, status: :internal_server_error
      end
    end

    # GET /v1/events/:id/organizer_payment_detail
    def organizer_payment_detail
      authorize @event, :show?

      payment_detail = find_organizer_payment_detail(@event)

      if payment_detail
        render json: {
          bank_name: payment_detail.bank_name,
          account_number: payment_detail.account_number,
          account_name: payment_detail.account_name
        }, status: :ok
      else
        render json: nil, status: :ok
      end
    end

    private

    # DRY principle: Find the event and handle 404
    def set_event
      # Use find_by! to automatically raise ActiveRecord::RecordNotFound, which
      # the ApplicationController should rescue and convert to a 404 response.
      # For restore and force_delete actions, use unscoped to find soft-deleted events
      @event = if action_name.in?(%w[restore force_delete])
                 Event.unscoped.find_by!(id: params[:id])
               else
                 Event.find_by!(id: params[:id])
               end
    end

    # DRY principle: Perform instance authorization
    def authorize_event
      authorize @event
    end

    # Strong parameters for Event resource
    def event_params
      params.require(:event).permit(
        :title,
        :description,
        :status,
        :multiple_scans,
        :start_date,
        :end_date,
        :webhook_url,
        :visibility,
        :use_ticket,
        :use_seat_ticketing,
        :use_exhibitor_kit,
        :allow_contractor_printing_services,
        :event_admin_id, # This will make assigned user as the event admin
        :use_business_matching,
        :use_wedding,
        :extra_guest_limit,
        :business_matching_webhook_url,
        :use_sponsorship,
        :use_event_leads,
        :payment_receipt_email, # backward compat — routed to event_email_setting
        :skip_webhooks,
        :logo,
        :remove_logo,
        labels_data: {}, # Allows JSONB hash updates
        booth_types: [], # Allows JSONB array updates
        event_email_setting_attributes: %i[sender_name sender_address contact_email payment_receipt_email]
      )
    end

    def handle_logo
      event_p = params[:event] || {}

      if event_p[:logo].present? && event_p[:logo].respond_to?(:read)
        @event.logo.attach(event_p[:logo])
      elsif ActiveModel::Type::Boolean.new.cast(event_p[:remove_logo])
        @event.logo.purge_later if @event.logo.attached?
      end
    end

    # Backward compat: if payment_receipt_email is sent at the top level,
    # route it into event_email_setting_attributes so the admin panel
    # doesn't need changes.
    def normalize_email_setting_params
      event_p = params[:event]
      return unless event_p&.key?(:payment_receipt_email)

      event_p[:event_email_setting_attributes] ||= {}
      event_p[:event_email_setting_attributes][:payment_receipt_email] = event_p[:payment_receipt_email]

      # Build the setting record if it doesn't exist yet
      @event.build_event_email_setting unless @event.event_email_setting
    end

    def find_organizer_payment_detail(event)
      # Find organizer (by global role) assigned to this event who has payment details
      organizer = event.event_assignments
                       .joins(:user)
                       .where(users: { role: :organizer })
                       .joins(user: :payment_detail)
                       .includes(user: :payment_detail)
                       .first

      organizer&.user&.payment_detail
    end
  end
end
