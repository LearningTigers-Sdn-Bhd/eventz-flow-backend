# app/mailers/user_mailer.rb
class UserMailer < ApplicationMailer
  def verification_code(user, code)
    @user = user
    @code = code
    @expires_in = 15 # minutes

    headers['Reply-To'] = 'support@saleschatalyst.com'
    headers['List-Unsubscribe'] = "<mailto:unsubscribe@saleschatalyst.com>, <https://eventzflow.com/unsubscribe?u=#{@user.id}>"
    headers['List-Unsubscribe-Post'] = 'List-Unsubscribe=One-Click'

    mail(
      from: 'EventzFlow Support <support@saleschatalyst.com>',
      to: @user.email,
      subject: 'Verify your email address'
    )
  end
end
