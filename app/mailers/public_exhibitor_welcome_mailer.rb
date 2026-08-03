class PublicExhibitorWelcomeMailer < ApplicationMailer
  LOGIN_URL = 'https://eventzflow.com/auth?login'.freeze

  def welcome(email, temporary_password, name = nil)
    @email = email
    @temporary_password = temporary_password
    @name = name
    @login_url = LOGIN_URL

    mail(to: email, subject: 'Welcome to EventzFlow - your exhibitor account is ready')
  end
end
