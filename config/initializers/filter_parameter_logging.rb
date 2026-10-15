# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  # RfiDex sends the raw device key in Authorization, and its search query is
  # the guest's name/email/phone. Neither belongs in a log line. `q` is matched
  # exactly so ordinary params containing the letter are still logged.
  :authorization, /\Aq\z/
]
