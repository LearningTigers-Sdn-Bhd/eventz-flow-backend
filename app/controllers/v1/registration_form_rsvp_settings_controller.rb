# frozen_string_literal: true

module V1
  class RegistrationFormRsvpSettingsController < ApplicationController
    before_action :set_event
    before_action :set_registration_form
    before_action -> { authorize @event, :update? }

    def show
      render json: setting_payload(setting), status: :ok
    end

    def update
      if setting.update(setting_params)
        render json: setting_payload(setting), status: :ok
      else
        render json: { errors: setting.errors.full_messages }, status: :unprocessable_content
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_registration_form
      @registration_form = @event.registration_forms.find(params[:registration_form_id])
    end

    def setting
      @setting ||= @registration_form.registration_form_rsvp_setting || @registration_form.create_registration_form_rsvp_setting!
    end

    def setting_params
      params.require(:registration_form_rsvp_setting).permit(
        :enabled,
        :rsvp_required,
        :rsvp_expires_in_hours,
        :review_sla_hours,
        :notify_by_date
      )
    end

    def setting_payload(record)
      record.as_json(
        only: %i[
          id
          registration_form_id
          enabled
          rsvp_required
          rsvp_expires_in_hours
          review_sla_hours
          notify_by_date
          created_at
          updated_at
        ]
      )
    end
  end
end
