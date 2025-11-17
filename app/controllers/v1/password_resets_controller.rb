module V1
  class PasswordResetsController < ApplicationController
    skip_before_action :authenticate_user!, only: %i[request_reset_password verify_reset_password_request reset_password]
    skip_before_action :require_verified_email!, only: %i[request_reset_password verify_reset_password_request reset_password]

    def request_reset_password
      email = params[:email].to_s.strip.downcase
      if email.blank?
        return error_response(message: 'Email is required', errors: [{ field: 'email', message: 'Email is required' }], status: :unprocessable_content)
      end

      user = User.find_by(email: email)
      if user.present?
        raw_token = ::PasswordReset.issue_for!(user)
        UserMailer.password_reset(user, raw_token).deliver_now
      end

      success_response(message: 'If that email exists, instructions have been sent.')
    end

    def verify_reset_password_request
      raw_token = params[:token].to_s
      record = ::PasswordReset.find_valid_by_token(raw_token)

      unless record&.usable?
        return error_response(message: 'Invalid or expired token', errors: [{ field: 'token', message: 'Invalid or expired token' }], status: :unprocessable_content)
      end

      success_response(message: 'Token is valid')
    end

    def reset_password
      raw_token = params[:token].to_s
      password = params[:password].to_s
      password_confirmation = params[:password_confirmation].to_s

      if password.blank? || password_confirmation.blank?
        return error_response(message: 'Password and confirmation are required', errors: [{ field: 'password', message: 'Password and confirmation are required' }], status: :unprocessable_content)
      end

      record = ::PasswordReset.find_valid_by_token(raw_token)
      unless record&.usable?
        return error_response(message: 'Invalid or expired token', errors: [{ field: 'token', message: 'Invalid or expired token' }], status: :unprocessable_content)
      end

      user = record.user
      unless password == password_confirmation
        return error_response(message: 'Password confirmation does not match', errors: [{ field: 'password_confirmation', message: "doesn't match Password" }], status: :unprocessable_content)
      end

      user.password = password
      user.password_confirmation = password_confirmation
      if user.save
        record.revoke!
        ::PasswordReset.where(user_id: user.id, revoked_at: nil).update_all(revoked_at: Time.current)
        return success_response(message: 'Password has been reset')
      else
        return error_response(message: 'Validation failed', errors: user.errors.full_messages.map { |m| { field: 'password', message: m } }, status: :unprocessable_content)
      end
    end
  end
end
