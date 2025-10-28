class ApplicationMailer < ActionMailer::Base
  default from: ENV.fetch("MAIL_FROM", "noreply@uniseekai.com")
  layout "mailer"
end
