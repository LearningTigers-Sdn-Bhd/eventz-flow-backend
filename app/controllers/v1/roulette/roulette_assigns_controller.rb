module V1
  module Roulette
    class RouletteAssignsController < ApplicationController
      before_action :set_event
      before_action :set_session

      # GET /v1/events/:event_id/roulette/sessions/:session_id/assigns
      def index
        authorize @session, :show?
        @assigns = @session.roulette_assigns.includes(:user)

        success_response(
          data: @assigns.map { |a| format_assign_response(a) },
          message: 'Success'
        )
      end

      # POST /v1/roulette/sessions/:session_id/assigns
      def create
        authorize @session, :update?

        user_id = params[:user_id]
        user_email = params[:user_email]

        unless user_id.present? || user_email.present?
          return error_response(
            message: 'Either user_id or user_email must be provided',
            status: :unprocessable_content
          )
        end

        # Find user by id or email
        user = if user_id.present?
                 User.find_by(id: user_id)
               else
                 User.find_by(email: user_email)
               end

        unless user
          return error_response(
            message: 'User not found',
            status: :not_found
          )
        end

        @assign = @session.roulette_assigns.build(user: user)
        authorize @assign

        if @assign.save
          success_response(
            data: format_assign_response(@assign),
            message: 'User assigned successfully',
            status: :created
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@assign),
            status: :unprocessable_content
          )
        end
      end

      # DELETE /v1/roulette/sessions/:session_id/assigns/:id
      def destroy
        authorize @session, :update?
        @assign = @session.roulette_assigns.find(params[:id])
        @assign.destroy
        success_response(
          message: 'Assignment removed successfully'
        )
      end

      private

      def set_event
        @event = Event.friendly.find(params[:event_id])
      end

      def set_session
        @session = @event.roulette_sessions.find(params[:session_id])
      end

      def format_assign_response(assign)
        {
          id: assign.id,
          roulette_session_id: assign.roulette_session_id,
          user: {
            id: assign.user.id,
            full_name: assign.user.full_name,
            email: assign.user.email
          },
          created_at: assign.created_at.iso8601,
          updated_at: assign.updated_at.iso8601
        }
      end
    end
  end
end
