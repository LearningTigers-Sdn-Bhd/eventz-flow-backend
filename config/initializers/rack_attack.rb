require 'digest'

class Rack::Attack
  # 1. Allow all Localhost traffic (Development/Test)
  safelist('allow-localhost') do |req|
    '127.0.0.1' == req.ip || '::1' == req.ip
  end

  # 2. General IP Limit (Prevent DoS)
  # Limit all requests to 300 per minute per IP
  throttle('req/ip', limit: 300, period: 1.minute) do |req|
    req.ip unless req.path.start_with?('/assets', '/active_storage')
  end

  # 3. Login Protection (Brute Force)
  # Limit login attempts to 5 per minute per EMAIL
  throttle('login/email', limit: 5, period: 1.minute) do |req|
    if req.path == '/v1/auth/login' && req.post?
      # Normalize email
      req.params['email'].to_s.downcase.gsub(/\s+/, "")
    end
  end

  # 4. Login Protection (IP based fallback)
  # Limit login attempts to 20 per minute per IP (in case email varies)
  throttle('login/ip', limit: 20, period: 1.minute) do |req|
    if req.path == '/v1/auth/login' && req.post?
      req.ip
    end
  end

  # 5. Registration Protection (Bot Accounts)
  # Limit registrations to 5 per hour per IP
  throttle('register/ip', limit: 5, period: 1.hour) do |req|
    if req.path == '/v1/auth/register' && req.post?
      req.ip
    end
  end

  # 6. Verification Code Protection (Spamming)
  # Limit "Resend Code" to 5 per hour per IP
  throttle('verification/ip', limit: 5, period: 1.hour) do |req|
    if req.path == '/v1/auth/send-verification-code' && req.post?
      req.ip
    end
  end

  # 7. Refresh Token Protection
  # Limit refresh token usage to 20 per minute per IP
  throttle('refresh/ip', limit: 20, period: 1.minute) do |req|
    if req.path == '/v1/auth/refresh_token' && req.post?
      req.ip
    end
  end

  # 8. Public Registration Protection (Walk-in spam)
  # Limit public registration to 10 per hour per IP
  throttle("public_registration/ip", limit: 10, period: 1.hour) do |req|
    if req.path.match?(/\/v1\/public\/events\/.*\/register/) && req.post?
      req.ip
    end
  end

  # 9. Public Registration by Email (prevent same email spam)
  # Limit by email to 10 per hour per email
  throttle("public_registration/email", limit: 10, period: 1.hour) do |req|
    if req.path.match?(/\/v1\/public\/events\/.*\/register/) && req.post?
      req.params['attendee_email'].presence
    end
  end

  # 10. Public Registration Document Uploads (storage flooding)
  # 5 documents per registration × a few retries
  throttle('public_upload/ip', limit: 20, period: 1.hour) do |req|
    if req.path.match?(%r{/v1/public/events/.*/registration_uploads}) && req.post?
      req.ip
    end
  end

  throttle('exhibitor_ic_upload/ip', limit: 50, period: 1.hour) do |req|
    req.ip if req.path.match?(%r{/v1/public/events/.*/exhibitor_ic_upload}) && req.post?
  end

  throttle('customs_declaration_upload/ip', limit: 50, period: 1.hour) do |req|
    req.ip if req.path.match?(%r{/v1/public/events/.*/customs_declaration_upload}) && req.post?
  end

  throttle('exhibitor_access_request/ip', limit: 50, period: 1.hour) do |req|
    req.ip if req.path.match?(%r{/v1/public/events/.*/exhibitor_access_requests$}) && req.post?
  end

  throttle('exhibitor_access_request/email', limit: 30, period: 1.hour) do |req|
    if req.path.match?(%r{/v1/public/events/.*/exhibitor_access_requests$}) && req.post?
      Digest::SHA256.hexdigest(req.params['email'].to_s.strip.downcase)
    end
  end

  throttle('exhibitor_access_session/ip', limit: 100, period: 1.hour) do |req|
    req.ip if req.path.match?(%r{/v1/public/events/.*/exhibitor_access_sessions$}) && req.post?
  end

  throttle('public_exhibitor_booking/ip', limit: 100, period: 1.hour) do |req|
    if req.path.match?(%r{/v1/public/events/.*/exhibitor_bookings}) && %w[POST PATCH].include?(req.request_method)
      req.ip
    end
  end

  throttle('public_exhibitor_booking/session', limit: 100, period: 1.hour) do |req|
    if req.path.match?(%r{/v1/public/events/.*/exhibitor_bookings}) && %w[POST PATCH].include?(req.request_method)
      Digest::SHA256.hexdigest(req.get_header('HTTP_AUTHORIZATION').to_s)
    end
  end

  # 11. Public Payment Proof Uploads
  throttle('payment_proof/ip', limit: 10, period: 1.hour) do |req|
    if req.path.match?(%r{/v1/public/events/.*/tickets/.*/payment_proof}) && (req.post? || req.delete?)
      req.ip
    end
  end

  # 12. Field Availability Check (membership-number enumeration)
  throttle('field_availability/ip', limit: 60, period: 1.hour) do |req|
    if req.path.match?(%r{/v1/public/events/.*/field_availability}) && req.get?
      req.ip
    end
  end

  # Response for throttled requests
  self.throttled_responder = lambda do |req|
    match_data = (req.respond_to?(:env) ? req.env['rack.attack.match_data'] : nil) ||
      (req.respond_to?(:get_header) ? req.get_header('rack.attack.match_data') : nil) || {}
    now = match_data[:epoch_time] || Time.now.to_i
    period = match_data[:period] || 60
    limit = match_data[:limit] || 0

    headers = {
      'RateLimit-Limit' => limit.to_s,
      'RateLimit-Remaining' => '0',
      'RateLimit-Reset' => (now + (period - (now % period))).to_s,
      'Content-Type' => 'application/json'
    }

    [429, headers, [{ message: 'Too many requests. Please try again later.', status: 'too_many_requests' }.to_json]]
  end
end
