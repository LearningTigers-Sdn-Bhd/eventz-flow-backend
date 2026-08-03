require 'cgi'

class PublicExhibitorAccessMailer < ApplicationMailer
  def access_link(event, email, challenge)
    @event = event
    base_url = event.normalized_public_registration_url.to_s.chomp('/')
    secure_url = base_url.start_with?('https://')
    local_url = !Rails.env.production? && base_url.match?(%r{\Ahttp://(localhost|127\.0\.0\.1)(:\d+)?\z})
    raise ArgumentError, 'Secure public registration URL is not configured' unless secure_url || local_url

    @access_url = "#{base_url}/exhibitor-registration/access?challenge=#{CGI.escape(challenge)}"

    mail(to: email, subject: "Access your exhibitor bookings for #{event.title}")
  end
end
