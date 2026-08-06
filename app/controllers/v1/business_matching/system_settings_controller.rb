# frozen_string_literal: true

module V1
  module BusinessMatching
    class SystemSettingsController < ApplicationController
      # GET /v1/business_matching/system_settings
      def show
        setting = SystemSetting.instance
        authorize setting

        render json: serialize(setting), status: :ok
      end

      # PUT/PATCH /v1/business_matching/system_settings
      def update
        setting = SystemSetting.instance
        authorize setting

        if setting.update(setting_params)
          render json: serialize(setting), status: :ok
        else
          render json: { errors: setting.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def serialize(setting)
        {
          default_hours: setting.business_matching_default_hours,
          hours_editable_default: setting.business_matching_hours_editable_default
        }
      end

      def setting_params
        permitted = params.permit(:hours_editable_default, default_hours: [:start_time, :end_time])
        attrs = {}
        attrs[:business_matching_hours_editable_default] = permitted[:hours_editable_default] if params.key?(:hours_editable_default)
        attrs[:business_matching_default_hours] = params[:default_hours].map { |b| b.permit(:start_time, :end_time).to_h } if params[:default_hours].present?
        attrs
      end
    end
  end
end
