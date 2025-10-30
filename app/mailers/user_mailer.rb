# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer

  default from: "EventzFlow App Notifications <notifications@updates.eventzflow.com>"

  def verification_code(user, code)
    @user = user
    @code = code
    @expires_in = 15 # minutes
    @random_id = SecureRandom.hex(10)

    mail(
      to: [@user.email],
      reply_to: 'support@saleschatalyst.com',
      subject: 'Verify your email address',
      tags: {
        "name": "category", "value": "confirm_email"
      },
      headers: {
        "X-Entity-Ref-ID": "UID#{@user.id}-#{@random_id}"
      },
      options: {
        idempotency_key: "verify_email/#{@user.id}-#{@random_id}"
      }
    )
  end

  def password_reset(user, code)
    @user = user

    redirect_base_url = ENV.fetch("REDIRECT_BASE_URL", "http://localhost:3001")
    @reset_password_url = "#{redirect_base_url}/forget-password/#{code}"

    @expires_in = 15 # minutes
    @random_id = SecureRandom.hex(10)

    mail(
      to: [@user.email],
      reply_to: 'support@saleschatalyst.com',
      subject: 'Request for the password reset.',
      tags: {
        "name": "category", "value": "reset_password"
      },
      headers: {
        "X-Entity-Ref-ID": "UID#{@user.id}-#{@random_id}"
      },
      options: {
        idempotency_key: "reset_password/#{@user.id}-#{@random_id}"
      }
    )
  end
end
