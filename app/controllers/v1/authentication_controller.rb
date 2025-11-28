# app/controllers/v1/authentication_controller.rb
module V1
  class AuthenticationController < ApplicationController
    skip_before_action :authenticate_user!, only: %i[login register refresh_token register_invited_vendor check_account]
    skip_before_action :require_verified_email!, only: %i[logout send_verification_code verify_email refresh_token register_invited_vendor check_account join_event_as_vendor]

    def register
      @user = User.new(register_params)
      authorize @user, :create?

      if @user.save
        # Generate and send verification code
        code = EmailVerification.create_for_user(@user)
        UserMailer.verification_code(@user, code).deliver_now

        tokens = JwtService.generate_tokens(@user)

        success_response(
          data: {
            user: @user.slice(:id, :full_name, :email, :role).merge(email_verified: @user.email_verified?),
            **tokens
          },
          message: 'User registered successfully. Please verify your email.',
          status: :created
        )
      else
        error_response(message: 'Validation Error', errors: format_validation_errors(@user), status: :unprocessable_content)
      end
    end

  # POST /v1/login
  def login
    email = login_params[:email]
    return error_response(message: 'Email is required', errors: [{ field: 'email', message: 'Email is required' }], status: :unprocessable_content) if email.blank?

    user = User.find_by(email: email.downcase)

    # Check if user exists, is active, and credentials are valid
    if user&.active? && user&.authenticate(login_params[:password])
      tokens = JwtService.generate_tokens(user)

      success_response(
        data: {
          user: user.slice(:id, :full_name, :email, :role).merge(email_verified: user.email_verified?),
          **tokens
        },
        message: 'Login successful',
        status: :ok
      )
    else
      # Provide specific error messages based on the failure reason
      if user.nil?
        error_response(
          message: 'Authentication failed',
          errors: [{ field: 'email', message: 'Email not found' }],
          status: :unauthorized
        )
      elsif !user.active?
        error_response(
          message: 'Authentication failed',
          errors: [{ field: 'account', message: 'Account is inactive' }],
          status: :unauthorized
        )
      else
        error_response(
          message: 'Authentication failed',
          errors: [{ field: 'password', message: 'Invalid password' }],
          status: :unauthorized
        )
      end
    end
  end

  # DELETE /v1/logout
  def logout
    if current_user
      current_user.update!(jti: SecureRandom.uuid)
      success_response(
        message: 'Logged out successfully',
        status: :ok
      )
    else
      error_response(
        message: 'Logout failed',
        errors: [{ field: 'user', message: 'User not found or not authenticated' }],
        status: :unauthorized
      )
    end
  end

  # POST /v1/auth/send-verification-code
  def send_verification_code
    # Generate and send new verification code for current user
    code = EmailVerification.create_for_user(current_user)
    UserMailer.verification_code(current_user, code).deliver_now

    success_response(
      message: 'Verification code sent successfully',
      status: :ok
    )
  end

  # POST /v1/auth/verify-email
  def verify_email
    code = params[:code]
    if code.blank?
      return error_response(message: 'Verification code is required', errors: [{ field: 'code', message: 'Verification code is required' }], status: :unprocessable_content)
    end

    if EmailVerification.verify_code(current_user, code)
      # Reload user to get updated email_verified_at
      current_user.reload

      success_response(
        data: {
          user: current_user.slice(:id, :full_name, :email, :role, :phone).merge(email_verified: current_user.email_verified?)
        },
        message: 'Email verified successfully',
        status: :ok
      )
    else
      error_response(message: 'Invalid verification code', errors: [{ field: 'code', message: 'Invalid or expired code' }], status: :unauthorized)
    end
  end

  def refresh_token
    refresh_token = params[:refresh_token]
    unless refresh_token
      return error_response(message: 'Refresh token is required', errors: [{ field: 'refresh_token', message: 'Refresh token is required' }], status: :unprocessable_content)
    end

    tokens = JwtService.refresh_access_token(refresh_token)
    success_response(
      data: tokens,
      message: 'Access token refreshed successfully'
    )
  rescue CustomError::Unauthorized => e
    return error_response(message: 'Invalid refresh token', errors: [{ field: 'refresh_token', message: e.message }], status: :unauthorized)
  end

  # POST /v1/auth/register_invited_vendor
  def register_invited_vendor
    token = params[:token]

    if token.blank?
      return error_response(
        message: 'Token is required',
        errors: [{ field: 'token', message: 'Invitation token is required' }],
        status: :unprocessable_content
      )
    end

    begin
      payload = Rails.application.message_verifier(:vendor_invite).verify(token)
      payload = payload.with_indifferent_access if payload.is_a?(Hash)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      return error_response(
        message: 'Invalid invitation link',
        errors: [{ field: 'token', message: 'Invalid or malformed invitation token' }],
        status: :unauthorized
      )
    end

    exp = payload[:exp] || payload['exp']
    event_id = payload[:event_id] || payload['event_id']
    organizer_id = payload[:organizer_id] || payload['organizer_id']

    if exp.nil? || exp < Time.current.to_i
      return error_response(
        message: 'Invitation link expired',
        errors: [{ field: 'token', message: 'This invitation link has expired' }],
        status: :gone
      )
    end

    event = Event.find_by(id: event_id)
    unless event
      return error_response(
        message: 'Event not found',
        errors: [{ field: 'event', message: 'The event for this invitation no longer exists' }],
        status: :not_found
      )
    end

    ActiveRecord::Base.transaction do
      user_attrs = invited_vendor_params.merge(
        role: :vendor,
        email_verified_at: Time.current
      )
      user_attrs[:created_by_id] = organizer_id if organizer_id.present?

      @user = User.new(user_attrs)

      unless @user.save
        return error_response(
          message: 'Validation Error',
          errors: format_validation_errors(@user),
          status: :unprocessable_content
        )
      end

      # Update vendor profile if vendor_profile params provided
      # (VendorProfile is auto-created by User model callback)
      if params[:vendor_profile].present? && @user.vendor_profile.present?
        unless @user.vendor_profile.update(invited_vendor_profile_params)
          return error_response(
            message: 'Validation Error',
            errors: format_validation_errors(@user.vendor_profile),
            status: :unprocessable_content
          )
        end
      end

      # Create event vendor with optional attributes
      event_vendor_attrs = invited_event_vendor_params || {}
      event_vendor = EventVendor.create_for_event(event, @user, event_vendor_attrs)

      unless event_vendor.persisted?
        raise ActiveRecord::Rollback
      end

      tokens = JwtService.generate_tokens(@user)

      success_response(
        data: {
          user: @user.slice(:id, :full_name, :email, :role, :phone).merge(email_verified: @user.email_verified?),
          event_vendor: {
            id: event_vendor.id,
            event_id: event.id,
            event_title: event.title,
            type: event_vendor.type
          },
          **tokens
        },
        message: 'Vendor registered successfully',
        status: :created
      )
    end
  end

  # PATCH /v1/auth/password
  def password_update
    current_password = params[:current_password]
    new_password = params[:new_password]
    confirm_new_password = params[:confirm_new_password]

    # Validate required fields
    missing_fields = []
    missing_fields << { field: 'current_password', message: 'Current password is required' } if current_password.blank?
    missing_fields << { field: 'new_password', message: 'New password is required' } if new_password.blank?
    missing_fields << { field: 'confirm_new_password', message: 'Confirm new password is required' } if confirm_new_password.blank?
    if missing_fields.any?
      return error_response(message: 'Validation Error', errors: missing_fields, status: :unprocessable_content)
    end

    # Verify current password
    unless current_user.authenticate(current_password)
      return error_response(message: 'Authentication failed', errors: [{ field: 'current_password', message: 'Current password is incorrect' }], status: :unauthorized)
    end

    # Ensure new password and confirmation match
    unless new_password == confirm_new_password
      return error_response(message: 'Validation Error', errors: [{ field: 'confirm_new_password', message: 'Passwords do not match' }], status: :unprocessable_content)
    end

    # Attempt to update the password (leverages has_secure_password validations)
    if current_user.update(password: new_password, password_confirmation: confirm_new_password)
      # Rotate JTI to invalidate existing tokens/sessions and issue fresh tokens
      current_user.update!(jti: SecureRandom.uuid)
      tokens = JwtService.generate_tokens(current_user)

      return success_response(
        data: tokens,
        message: 'Password updated successfully',
        status: :ok
      )
    else
      return error_response(
        message: 'Validation Error',
        errors: format_validation_errors(current_user),
        status: :unprocessable_content
      )
    end
  end

  # GET /v1/auth/check_account?email=xxx OR ?phone=xxx
  def check_account
    email = params[:email]&.downcase&.strip
    phone = params[:phone]&.strip

    if email.blank? && phone.blank?
      return error_response(
        message: 'Email or phone is required',
        errors: [{ field: 'identifier', message: 'Please provide email or phone number' }],
        status: :unprocessable_content
      )
    end

    # Find user by email or phone
    user = if email.present?
      User.find_by(email: email)
    else
      User.find_by(phone: phone)
    end

    if user.present?
      success_response(
        data: {
          exists: true,
          identifier_type: email.present? ? 'email' : 'phone',
          masked_identifier: mask_identifier(email || phone)
        },
        message: 'Account found'
      )
    else
      success_response(
        data: {
          exists: false,
          identifier_type: email.present? ? 'email' : 'phone'
        },
        message: 'No account found'
      )
    end
  end

  # POST /v1/auth/join_event_as_vendor
  def join_event_as_vendor
    token = params[:token]

    if token.blank?
      return error_response(
        message: 'Token is required',
        errors: [{ field: 'token', message: 'Invitation token is required' }],
        status: :unprocessable_content
      )
    end

    # Verify current user is a vendor
    unless current_user.role == 'vendor'
      return error_response(
        message: 'Invalid account type',
        errors: [{ field: 'user', message: 'Only vendor accounts can join events via invitation' }],
        status: :forbidden
      )
    end

    # Decode and verify the invitation token
    begin
      payload = Rails.application.message_verifier(:vendor_invite).verify(token)
      payload = payload.with_indifferent_access if payload.respond_to?(:with_indifferent_access)
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      return error_response(
        message: 'Invalid token',
        errors: [{ field: 'token', message: 'The invitation link is invalid' }],
        status: :unprocessable_content
      )
    end

    event_id = payload[:event_id] || payload['event_id']
    exp = payload[:exp] || payload['exp']

    # Check expiration
    if exp.present? && Time.at(exp) < Time.current
      return error_response(
        message: 'Token expired',
        errors: [{ field: 'token', message: 'The invitation link has expired' }],
        status: :unprocessable_content
      )
    end

    # Find the event
    event = Event.find_by(id: event_id)
    unless event
      return error_response(
        message: 'Event not found',
        errors: [{ field: 'event', message: 'The event no longer exists' }],
        status: :not_found
      )
    end

    # Check if already joined
    existing_event_vendor = EventVendor.find_by(event_id: event.id, vendor_id: current_user.id)
    if existing_event_vendor
      return error_response(
        message: 'Already joined',
        errors: [{ field: 'event', message: 'You have already joined this event as a vendor' }],
        status: :unprocessable_content
      )
    end

    # Create EventVendor record (type based on event settings)
    vendor_type = event.use_ticket? ? 'Exhibitor' : 'Merchant'
    event_vendor = EventVendor.new(
      event: event,
      vendor: current_user,
      type: vendor_type,
      redirect_url: params.dig(:event_vendor, :redirect_url),
      poster_url: params.dig(:event_vendor, :poster_url)
    )

    if event_vendor.save
      success_response(
        data: {
          event_vendor: {
            id: event_vendor.id,
            event_id: event.id,
            event_title: event.title
          }
        },
        message: 'Successfully joined event as vendor',
        status: :created
      )
    else
      error_response(
        message: 'Failed to join event',
        errors: format_validation_errors(event_vendor),
        status: :unprocessable_content
      )
    end
  end


  private

  def mask_identifier(value)
    return nil if value.blank?

    if value.include?('@')
      parts = value.split('@')
      "#{parts[0][0..1]}***@#{parts[1]}"
    else
      "****#{value[-4..]}"
    end
  end

  def login_params
    # Handle both nested and flat parameter formats
    if params[:user].present?
      params.require(:user).permit(:email, :password)
    else
      params.permit(:email, :password)
    end
  end

  def register_params
    user_params = params.require(:user).permit(:email, :password, :password_confirmation, :full_name, :phone)
    # Ensure email is downcased
    user_params[:email] = user_params[:email].downcase if user_params[:email].present?
    user_params
  end

  def invited_vendor_params
    user_params = params.require(:user).permit(:email, :password, :password_confirmation, :full_name, :phone)
    user_params[:email] = user_params[:email].downcase if user_params[:email].present?
    user_params
  end

  def invited_vendor_profile_params
    return {} unless params[:vendor_profile].present?
    params.require(:vendor_profile).permit(:description, :category, :person_in_charge, :address, :notes)
  end

  def invited_event_vendor_params
    return {} unless params[:event_vendor].present?
    params.require(:event_vendor).permit(:redirect_url, :poster_url, :qr_url)
  end
end
end
