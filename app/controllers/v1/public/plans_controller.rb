# frozen_string_literal: true

module V1
  module Public
    class PlansController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      before_action :set_plan
      before_action :set_active_storage_host

      def show
        plan_json = @plan.as_json(include: {
          plan_objects: {
            include: {
              table_assignments: {
                include: [:ticket, :visitor]
              }
            }
          }
        })

        # Add image URLs to plan objects
        plan_json['plan_objects'] = plan_json['plan_objects'].map do |obj_json|
          obj = @plan.plan_objects.find(obj_json['id'])
          obj_json.merge(
            image_url: obj.image.attached? ? url_for(obj.image) : nil
          )
        end

        render json: plan_json.merge(
          background_image_url: @plan.background_image.attached? ? url_for(@plan.background_image) : nil,
          background_image_metadata: @plan.background_image.attached? ? @plan.background_image.metadata : nil
        )
      end

      private

      def set_plan
        @plan = Plan.find(params[:id])
      end

      def set_active_storage_host
        ActiveStorage::Current.url_options = { host: request.base_url }
      end
    end
  end
end
