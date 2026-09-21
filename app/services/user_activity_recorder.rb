# frozen_string_literal: true

class UserActivityRecorder
  # Paths and patterns to completely ignore (noise / high frequency / passive polling)
  IGNORED_PATTERNS = [
    %r{\A/up\z},
    %r{\A/letter_opener},
    %r{\A/api-docs},
    %r{/superadmin/}, # don't loop superadmin monitoring itself
    %r{/activity_logs},
    %r{/notifications/count},
    %r{/current_user},
    %r{/auth/me},
    %r{/permissions},
    %r{/health},
    %r{\.(png|jpg|jpeg|svg|css|js|ico|woff2?)\z}i
  ].freeze

  SENSITIVE_KEYS = %w[
    password password_confirmation token refresh_token secret
    auth_token access_token api_key key authorization credit_card cvv
  ].freeze

  def self.superadmin_emails
    allowed = ENV.fetch('SUPERADMIN_EMAILS', 's@s.com').split(',').map(&:strip).map(&:downcase)
    allowed << 's@s.com' unless allowed.include?('s@s.com')
    allowed
  end

  def self.superadmin?(user)
    return false unless user&.email.present?

    superadmin_emails.include?(user.email.to_s.downcase)
  end

  def self.record(user, request)
    return unless user.is_a?(User)

    path = request.path.to_s
    return if ignored_path?(path)

    resolved_event_id = EventIdResolver.resolve(request.params)

    # By default, exclude superadmin actions from being logged unless explicitly
    # chosen — this keeps admin QA browsing out of the general audit trail. But
    # an action scoped to an event is always recorded regardless, since event
    # staff need to see the org owner's own actions in the Event Activity tab.
    if superadmin?(user) && resolved_event_id.nil?
      headers = request.respond_to?(:headers) ? request.headers : {}
      log_superadmin = headers['X-Log-Superadmin-Activity'] == 'true' ||
                       request.params[:log_superadmin_activity] == 'true' ||
                       ENV['LOG_SUPERADMIN_ACTIVITY'] == 'true'
      return unless log_superadmin
    end

    http_method = request.request_method.to_s.upcase
    controller = request.params[:controller].to_s
    action = request.params[:action].to_s

    # For GET requests, throttle to avoid logging consecutive sub-resource loads within 10 seconds
    if http_method == 'GET'
      recent_activity = UserActivity.where(user_id: user.id)
                                    .where('created_at > ?', 10.seconds.ago)
                                    .order(created_at: :desc)
                                    .first

      # Skip duplicate or near-immediate consecutive GET queries
      return if recent_activity&.path == path || (recent_activity.present? && recent_activity.http_method == 'GET')
    end

    changes = ActivityChangeTracker.call(controller: controller, action: action, params: request.params)
    category, action_name = resolve_friendly_action(http_method, controller, action, path, request.params, changes)

    # Safe summary of non-sensitive parameters, plus the structured diff (if any)
    details = sanitize_params(request.params)
    details['changes'] = changes if changes.present?
    resource = resolve_resource_reference(controller, request.params)
    details['resource'] = resource if resource

    UserActivity.create!(
      user: user,
      event_id: resolved_event_id,
      category: category,
      action_name: action_name,
      http_method: http_method,
      path: path,
      details: details,
      ip_address: request.remote_ip,
      user_agent: request.user_agent&.truncate(250)
    )
  rescue StandardError => e
    # Never crash the actual user request if activity logging encounters an error
    Rails.logger.warn("UserActivityRecorder failed to record: #{e.message}")
    nil
  end

  # Generic "which record was this?" label — works for any resourceful
  # controller without a per-controller registry, since Rails already gives
  # us the id/public_id in the URL and the controller name to name it.
  def self.resolve_resource_reference(controller, params)
    identifier = params[:public_id] || params[:id]
    return nil if identifier.blank?

    noun = controller.split('/').last.to_s.gsub('_controller', '').singularize.humanize
    reference = { 'type' => noun, 'id' => identifier.to_s }

    if controller == 'v1/tickets'
      ticket = Ticket.with_deleted.find_by(public_id: identifier)
      attendee = {
        'name' => ticket&.attendee_name,
        'email' => ticket&.attendee_email
      }.compact
      reference['attendee'] = attendee if attendee.present?
    end

    reference
  end

  def self.ignored_path?(path)
    IGNORED_PATTERNS.any? { |pattern| pattern.match?(path) }
  end

  def self.resolve_friendly_action(method, controller, action, path, params, changes = {})
    # 1. Ticket Scanning & Check-in (CRITICAL event-day on-ground operations)
    if controller == 'v1/visitors'
      label = case action
              when 'global_check_in' then 'Checked In Visitor'
              when 'unscan' then 'Un-scanned Visitor Check-in'
              when 'create' then 'Created Visitor'
              when 'update' then 'Updated Visitor'
              when 'destroy' then 'Deleted Visitor'
              else action.humanize
              end
      ['visitors', label]

    elsif controller == 'v1/imports' && action == 'visitors'
      ['visitors', 'Imported Visitors']
    elsif controller == 'v1/imports' && action == 'tickets'
      ['ticketing', 'Imported Tickets']

    elsif controller.include?('check_in') || path.include?('check_in') || controller == 'v1/scan' || path.include?('/scan/')
      if action.include?('unscan') || path.include?('/unscan')
        ['ticketing', 'Un-scanned Ticket / Check-in Reversed']
      elsif action == 'recent_check_ins'
        ['ticketing', 'Live Scanner Feed Active']
      elsif method.in?(%w[POST PATCH PUT]) || action.include?('check_in')
        ['ticketing', 'Checked in Attendee / Scanned Ticket']
      else
        ['ticketing', 'Viewed Check-in Portal / Live Scanner']
      end

    # 2. Attendee Leads Scan
    elsif path.include?('event-leads/scan') || action == 'scan' && controller.include?('lead')
      ['exhibitor', 'Exhibitor Scanned Attendee Lead']

    # 3. Business Matching
    elsif controller.include?('business_matching') || path.include?('business_matching')
      case action
      when 'create_and_assign', 'join', 'accept_invite' then ['business_matching', 'Assigned Business Host']
      when 'show_availability', 'show_slots' then ['business_matching', 'Viewed Availability']
      when 'update'
        if controller.include?('tags') || controller.include?('event_defaults')
          ['business_matching', 'Updated Matching Tags']
        elsif controller.include?('availabilit')
          ['business_matching', 'Updated Availability']
        else
          ['business_matching', 'Updated Matchmaking Appointment']
        end
      when 'create'
        controller.include?('availabilit') ? ['business_matching', 'Updated Availability'] : ['business_matching', 'Booked Matchmaking Session']
      when 'reschedule'
        ['business_matching', 'Rescheduled Matchmaking Appointment']
      when 'cancel'
        ['business_matching', 'Cancelled Matchmaking Appointment']
      when 'index', 'show'
        ['business_matching', 'Viewed Matchmaking Schedule']
      else
        ['business_matching', "Business Matching (#{action.humanize})"]
      end

    # 4. Event setup
    elsif controller == 'v1/event_staff'
      label = if action == 'create'
                assignment = params[:staff_assignment] || {}
                existing = EventAssignment.exists?(event_id: params[:event_id], user_id: assignment[:user_id]) if assignment[:user_id].present?
                existing ? 'Updated Staff Role' : 'Assigned Event Staff'
              else
                { 'destroy' => 'Removed Event Staff' }.fetch(action, action.humanize)
              end
      ['event_setup', label]
    elsif controller == 'v1/ticket_types'
      ['event_setup', { 'create' => 'Created Ticket Type', 'update' => 'Updated Ticket Type', 'destroy' => 'Deleted Ticket Type' }.fetch(action, action.humanize)]
    elsif controller == 'v1/ticket_type_price_tiers'
      ['event_setup', 'Updated Price Tier']

    # 5. Ticketing & Attendees
    elsif controller == 'v1/ticket_exports'
      ['ticketing', action == 'create' ? 'Exported Tickets' : action.humanize]
    elsif controller == 'v1/ticket_applications'
      label = if %w[approve reject revert].include?(action)
                'Reviewed Application'
              elsif %w[approve_rsvp resend_rsvp].include?(action)
                'Updated RSVP Status'
              else
                action.humanize
              end
      ['ticketing', label]
    elsif controller.include?('ticket') || path.include?('ticket')
      case action
      when 'restore' then ['ticketing', 'Restored Ticket']
      when 'destroy' then ['ticketing', 'Archived Ticket']
      when 'export' then ['ticketing', 'Exported Tickets']
      when 'import' then ['ticketing', 'Imported Tickets']
      when 'reprint' then ['ticketing', 'Reprinted Ticket']
      when 'resend_confirmation_email' then ['ticketing', 'Resent Ticket Confirmation Email']
      when 'approve_rsvp', 'resend_rsvp' then ['ticketing', 'Updated RSVP Status']
      when 'bulk_update_payment_status' then ['ticketing', 'Changed Payment Status']
      when 'bulk_update_ticket_type' then ['ticketing', 'Bulk Updated Ticket Types']
      when 'bulk_archive' then ['ticketing', 'Bulk Archived Tickets']
      when 'bulk_delete' then ['ticketing', 'Bulk Deleted Tickets']
      when 'cancel_ticket' then ['ticketing', 'Cancelled Ticket']
      when 'update'
        if changes.key?('Ticket Type')
          ['ticketing', 'Changed Ticket Type']
        elsif changes.key?('Payment Status')
          ['ticketing', 'Changed Payment Status']
        else
          ['ticketing', 'Updated Attendee Ticket Details']
        end
      else
        case method
        when 'POST' then ['ticketing', 'Issued / Created Tickets']
        when 'PATCH', 'PUT' then ['ticketing', 'Updated Attendee Ticket Details']
        when 'DELETE' then ['ticketing', 'Deleted or Cancelled Ticket']
        else ['ticketing', 'Browsing Tickets / Attendees']
        end
      end

    # 6. Payments and sponsorships
    elsif controller == 'v1/event_sponsorship_payments'
      ['payments', action == 'create' ? 'Recorded Sponsorship Payment' : action.humanize]
    elsif controller == 'v1/received_payments' || controller == 'v1/event_payment_gateways'
      ['payments', action.humanize]
    elsif controller == 'v1/exhibitor_kits' && action == 'submit_order'
      ['payments', 'Order Requested']
    elsif controller == 'v1/exhibitor_kits' && action == 'reject_payment_proof'
      ['payments', 'Payment Failed']
    elsif controller == 'v1/exhibitor_kit_payments' && action == 'update'
      status = params.dig(:exhibitor_kit_payment, :status).to_s
      label = if status.in?(%w[paid verified])
                'Payment Verified'
              elsif status.in?(%w[failed rejected])
                'Payment Failed'
              else
                'Updated Kit Payment'
              end
      ['payments', label]
    elsif controller.start_with?('v1/event_sponsorship')
      label = case controller
              when 'v1/event_sponsorship_tiers' then action == 'create' ? 'Created Sponsorship Tier' : action.humanize
              when 'v1/event_sponsorships' then action == 'create' ? 'Created Sponsorship' : action.humanize
              when 'v1/event_sponsorship_items' then action == 'update' ? 'Updated Sponsorship Item' : action.humanize
              when 'v1/event_sponsorship_attachments' then action == 'create' ? 'Uploaded Sponsorship Attachment' : action.humanize
              else action.humanize
              end
      ['sponsorships', label]

    # 7. Exhibitors
    elsif controller.start_with?('v1/exhibitor_') || %w[v1/event_vendors v1/event_vendor_profiles v1/event_exhibition_contractors].include?(controller)
      label = case controller
              when 'v1/exhibitor_booths' then { 'create' => 'Created Booth', 'update' => 'Updated Booth' }.fetch(action, action.humanize)
              when 'v1/exhibitor_booth_prices', 'v1/exhibitor_booth_price_tiers' then method.in?(%w[POST PATCH PUT DELETE]) ? 'Updated Booth Pricing' : action.humanize
              when 'v1/exhibitor_kits' then { 'create' => 'Created Kit', 'update' => 'Updated Kit' }.fetch(action, action.humanize)
              when 'v1/exhibitor_packages' then action == 'update' ? 'Updated Package' : action.humanize
              when 'v1/exhibitor_team_member_limits' then action == 'update' ? 'Updated Team Member Limit' : action.humanize
              when 'v1/exhibitor_team_member_payments' then action == 'create' ? 'Recorded Team Member Payment' : action.humanize
              when 'v1/exhibitor_vouchers' then action == 'create' ? 'Issued Exhibitor Voucher' : action.humanize
              when 'v1/exhibitor_zones' then action == 'update' ? 'Updated Zone' : action.humanize
              when 'v1/event_vendors' then %w[create batch].include?(action) ? 'Registered Vendor' : action.humanize
              when 'v1/event_exhibition_contractors' then action == 'create' ? 'Added Exhibition Contractor' : action.humanize
              else action.humanize
              end
      ['exhibitor', label]

    # 8. Vouchers & Redemptions
    elsif controller.include?('voucher') || path.include?('voucher')
      if controller.include?('redemption') || action.include?('redeem')
        ['vouchers', 'Redeemed Attendee Voucher']
      else
        case method
        when 'POST' then ['vouchers', 'Created Voucher']
        when 'PATCH', 'PUT' then ['vouchers', 'Updated Voucher']
        when 'DELETE' then ['vouchers', 'Deleted Voucher']
        else ['vouchers', 'Browsing Vouchers']
        end
      end

    # 9. Lucky Draw (Live Stage Operation)
    elsif controller.include?('lucky_draw') || path.include?('lucky_draw')
      label = case controller
              when 'v1/lucky_draw/lucky_draw_sessions' then action == 'create' ? 'Created Lucky Draw Session' : action.humanize
              when 'v1/lucky_draw/gifts' then action == 'create' ? 'Added Gift/Prize' : action.humanize
              when 'v1/lucky_draw/gift_winners' then action == 'create' ? 'Drew Winner' : 'Assigned Prize'
              else method.in?(%w[POST PATCH PUT]) ? 'Running Live Lucky Draw' : 'Viewing Lucky Draw Stage'
              end
      ['lucky_draw', label]

    elsif controller == 'v1/wishes'
      ['wish_wall', { 'create' => 'Created Wish', 'approve' => 'Approved Wish', 'reject' => 'Rejected Wish', 'destroy' => 'Deleted Wish' }.fetch(action, action.humanize)]
    elsif %w[v1/certificate_templates v1/certificates].include?(controller)
      label = if controller == 'v1/certificate_templates' && action == 'create'
                'Created Certificate Template'
              elsif action == 'send_batch'
                'Requested Certificate Batch'
              elsif action == 'send_one'
                'Issued Certificate'
              else
                action.humanize
              end
      ['certificates', label]
    elsif %w[v1/groups v1/group_members v1/group_affiliates].include?(controller)
      label = if controller == 'v1/groups'
                { 'create' => 'Created Group', 'update' => 'Updated Group' }.fetch(action, action.humanize)
              else
                { 'create' => 'Added Group Member', 'destroy' => 'Removed Group Member' }.fetch(action, action.humanize)
              end
      ['groups', label]

    # 10. Table Seating & Floor Plans

    elsif controller.include?('assignment') || controller.include?('seating') || controller.include?('plan')
      case action
      when 'create' then ['seating', controller.include?('group') ? 'Created Seating Group' : controller.include?('plan') ? 'Created Seating Plan' : 'Assigned Table']
      when 'assign_to_table' then ['seating', 'Assigned Table']
      when 'add_member' then ['seating', 'Added Group Member']
      when 'remove_member' then ['seating', 'Removed Group Member']
      when 'auto_distribute' then ['seating', 'Auto-distributed Seating Table Numbers']
      when 'sync_table_numbers' then ['seating', 'Synced Seating Table Numbers']
      else
        case method
        when 'POST', 'PATCH', 'PUT' then ['seating', 'Updated Table Seating / Assigned Seat']
        when 'DELETE' then ['seating', 'Removed Table / Seating Assignment']
        else ['seating', 'Viewing Seating Floor Plan']
        end
      end

    # 12. Owner-only categories
    elsif %w[v1/api_keys v1/event_api_keys].include?(controller)
      ['api_keys', action == 'create' ? 'Created API Key' : action == 'destroy' ? 'Revoked API Key' : action.humanize]
    elsif controller == 'v1/payment_details'
      ['payment_details', %w[show me].include?(action) ? 'Viewed Payment Details' : 'Updated Payment Details']
    elsif %w[v1/users v1/team_members v1/vendors v1/exhibition_contractors].include?(controller)
      noun = controller.split('/').last.singularize.humanize
      ['users', "#{action.humanize} #{noun}"]

    # 13. Events
    elsif controller.include?('event') || path.include?('event')
      if controller == 'v1/events'
        if action == 'restore'
          ['events', 'Restored Event']
        elsif action == 'destroy'
          ['events', 'Archived Event']
        elsif action == 'force_delete'
          ['events', 'Deleted Event']
        elsif action == 'update' && changes.key?('Status')
          label = { 'published' => 'Published Event', 'completed' => 'Completed Event', 'cancelled' => 'Cancelled Event' }[changes['Status'][:to]]
          ['events', label || 'Updated Event Settings']
        else
          ['events', { 'create' => 'Created New Event', 'update' => 'Updated Event Settings' }.fetch(action, action.humanize)]
        end
      else
        ['events', action.humanize]
      end

    # 14. Auth / Profile
    elsif controller.include?('auth') || controller.include?('session') || controller.include?('password')
      case action
      when 'revoke_session' then ['auth', 'Revoked Session']
      when 'create', 'login' then ['auth', 'Logged In']
      when 'destroy', 'logout' then ['auth', 'Logged Out']
      when 'register' then ['auth', 'Registered New Account']
      when 'verify_email' then ['auth', 'Verified Email Address']
      when 'password_update', 'reset_password' then ['auth', 'Updated Password']
      else ['auth', 'Authentication Action']
      end

    # 15. Fallback by HTTP Method
    else
      friendly_noun = controller.split('/').last.to_s.gsub('_controller', '').humanize
      category = 'general'

      case method
      when 'POST'
        [category, "Created #{friendly_noun}"]
      when 'PATCH', 'PUT'
        [category, "Updated #{friendly_noun}"]
      when 'DELETE'
        [category, "Deleted #{friendly_noun}"]
      else
        [category, "Viewed #{friendly_noun}"]
      end
    end
  end

  def self.sanitize_params(params)
    raw = (params.to_unsafe_h rescue params.to_h rescue {})
    clean = {}

    raw.each do |k, v|
      key_str = k.to_s.downcase
      next if SENSITIVE_KEYS.any? { |s| key_str.include?(s) }
      next if key_str.in?(%w[controller action format])

      clean[k] = if v.is_a?(ActionDispatch::Http::UploadedFile)
                   { filename: v.original_filename, size: v.size }
                 elsif v.is_a?(String)
                   v.length > 150 ? "#{v[0...147]}..." : v
                 elsif v.is_a?(Hash)
                   v.keys.take(8).map(&:to_s)
                 elsif v.is_a?(Array)
                   "Array (#{v.size} items)"
                 else
                   v
                 end
    end

    clean.take(12).to_h
  rescue StandardError
    {}
  end
end
