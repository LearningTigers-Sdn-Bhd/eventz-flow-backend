# frozen_string_literal: true

class UserActivityRecorder
  # Paths and patterns to completely ignore (noise / high frequency / passive polling)
  IGNORED_PATTERNS = [
    %r{\A/up\z},
    %r{\A/letter_opener},
    %r{\A/api-docs},
    %r{/superadmin/}, # don't loop superadmin monitoring itself
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

    # By default, exclude superadmin actions from being logged unless explicitly chosen
    if superadmin?(user)
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

    category, action_name = resolve_friendly_action(http_method, controller, action, path, request.params)

    # Safe summary of non-sensitive parameters
    details = sanitize_params(request.params)

    UserActivity.create!(
      user: user,
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
  end

  def self.ignored_path?(path)
    IGNORED_PATTERNS.any? { |pattern| pattern.match?(path) }
  end

  def self.resolve_friendly_action(method, controller, action, path, _params)
    # 1. Ticket Scanning & Check-in (CRITICAL event-day on-ground operations)
    if controller.include?('check_in') || path.include?('check_in') || controller == 'v1/scan' || path.include?('/scan/')
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
      when 'reschedule'
        ['business_matching', 'Rescheduled Matchmaking Appointment']
      when 'cancel'
        ['business_matching', 'Cancelled Matchmaking Appointment']
      when 'create'
        ['business_matching', 'Booked Matchmaking Session']
      when 'update'
        ['business_matching', 'Updated Matchmaking Appointment']
      when 'index', 'show'
        ['business_matching', 'Viewed Matchmaking Schedule']
      else
        ['business_matching', "Business Matching (#{action.humanize})"]
      end

    # 4. Ticketing & Attendees
    elsif controller.include?('ticket') || path.include?('ticket')
      case action
      when 'bulk_update_ticket_type' then ['ticketing', 'Bulk Updated Ticket Types']
      when 'bulk_archive' then ['ticketing', 'Bulk Archived Tickets']
      when 'bulk_delete' then ['ticketing', 'Bulk Deleted Tickets']
      when 'cancel_ticket' then ['ticketing', 'Cancelled Ticket']
      when 'resend_confirmation_email' then ['ticketing', 'Resent Ticket Confirmation Email']
      else
        case method
        when 'POST' then ['ticketing', 'Issued / Created Tickets']
        when 'PATCH', 'PUT' then ['ticketing', 'Updated Attendee Ticket Details']
        when 'DELETE' then ['ticketing', 'Deleted or Cancelled Ticket']
        else ['ticketing', 'Browsing Tickets / Attendees']
        end
      end

    # 5. Vouchers & Redemptions
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

    # 6. Lucky Draw (Live Stage Operation)
    elsif controller.include?('lucky_draw') || path.include?('lucky_draw')
      case method
      when 'POST', 'PATCH', 'PUT' then ['lucky_draw', 'Running Live Lucky Draw']
      else ['lucky_draw', 'Viewing Lucky Draw Stage']
      end

    # 7. Table Seating & Floor Plans
    elsif controller.include?('assignment') || controller.include?('seating') || controller.include?('plan')
      case action
      when 'auto_distribute' then ['seating', 'Auto-distributed Seating Table Numbers']
      when 'sync_table_numbers' then ['seating', 'Synced Seating Table Numbers']
      else
        case method
        when 'POST', 'PATCH', 'PUT' then ['seating', 'Updated Table Seating / Assigned Seat']
        when 'DELETE' then ['seating', 'Removed Table / Seating Assignment']
        else ['seating', 'Viewing Seating Floor Plan']
        end
      end

    # 8. Events
    elsif controller.include?('event') || path.include?('event')
      case method
      when 'POST' then ['events', 'Created New Event']
      when 'PATCH', 'PUT' then ['events', 'Updated Event Settings']
      when 'DELETE' then ['events', 'Deleted Event']
      else ['events', 'Viewing Event Details']
      end

    # 9. Exhibitor / Booths
    elsif controller.include?('exhibitor') || path.include?('exhibitor')
      case method
      when 'POST' then ['exhibitor', 'Exhibitor Registration / Booking']
      when 'PATCH', 'PUT' then ['exhibitor', 'Updated Exhibitor / Booth']
      else ['exhibitor', 'Managing Exhibitor Data']
      end

    # 10. Auth / Profile
    elsif controller.include?('auth') || controller.include?('session') || controller.include?('password')
      case action
      when 'create', 'login' then ['auth', 'Logged In']
      when 'destroy', 'logout' then ['auth', 'Logged Out']
      when 'register' then ['auth', 'Registered New Account']
      when 'verify_email' then ['auth', 'Verified Email Address']
      when 'password_update', 'reset_password' then ['auth', 'Updated Password']
      else ['auth', 'Authentication Action']
      end

    # 11. Fallback by HTTP Method
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

