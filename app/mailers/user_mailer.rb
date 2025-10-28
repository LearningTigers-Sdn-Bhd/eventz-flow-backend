# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def verification_code(user, code)
    @user = user
    @code = code
    @expires_in = 15 # minutes

    mail(
      to: @user.email,
      subject: 'Verify Your Email Address'
    )
  end
end
