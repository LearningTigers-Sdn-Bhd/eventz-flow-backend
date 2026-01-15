module V1
  module Roulette
    class RouletteSessionsController < ApplicationController
      before_action :set_session, only: [:show, :update, :destroy, :background_manager]

      # GET /v1/roulette/sessions
      def index
        @sessions = policy_scope(RouletteSession).ordered

        success_response(
          data: @sessions.map { |s| format_session_response(s) },
          message: 'Success'
        )
      end

      # GET /v1/roulette/sessions/:id
      def show
        authorize @session
        success_response(
          data: format_session_response(@session),
          message: 'Success'
        )
      end

      # POST /v1/roulette/sessions
      def create
        @session = current_user.roulette_sessions.build(session_params)
        authorize @session

        # Handle logo upload via Active Storage
        if params[:logo].present?
          @session.logo.attach(params[:logo])
        end

        if @session.save
          success_response(
            data: format_session_response(@session),
            message: 'Session created successfully',
            status: :created
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@session),
            status: :unprocessable_content
          )
        end
      end

      # PATCH /v1/roulette/sessions/:id
      def update
        authorize @session

        # Handle logo removal
        if params[:remove_logo] == 'true' || params[:remove_logo] == true
          @session.logo.purge if @session.logo.attached?
        elsif params[:logo].present?
          @session.logo.attach(params[:logo])
        end

        if @session.update(session_params)
          success_response(
            data: format_session_response(@session),
            message: 'Session updated successfully'
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@session),
            status: :unprocessable_content
          )
        end
      end

      # DELETE /v1/roulette/sessions/:id
      def destroy
        authorize @session
        @session.destroy
        success_response(
          message: 'Session deleted successfully'
        )
      end

      # GET /v1/roulette/sessions/:id/background-manager
      # POST /v1/roulette/sessions/:id/background-manager
      def background_manager
        authorize @session

        if request.get?
          # GET request - return current wrapper_background with full URL
          return success_response(
            data: {
              wrapper_background: format_wrapper_background(@session)
            },
            message: 'Success'
          )
        end

        # POST request - update wrapper_background
        use_image = ActiveModel::Type::Boolean.new.cast(params[:useImage]) || false

        # Preserve existing values from current wrapper_background
        current_bg = @session.wrapper_background || {}
        existing_background_color = current_bg['backgroundColor']

        if use_image
          # When useImage is true, either:
          # 1. A new image file is uploaded (params[:backgroundImage].present?)
          # 2. Or an existing image already exists
          unless params[:backgroundImage].present? || @session.background_image.attached?
            return error_response(
              message: 'Image file is required when useImage is true and no existing image is set',
              status: :unprocessable_content
            )
          end

          # If a new image is uploaded, attach it via Active Storage
          if params[:backgroundImage].present?
            @session.background_image.attach(params[:backgroundImage])
          end

          # Update wrapper_background: useImage true, preserve backgroundColor
          preserved_background_color = params[:backgroundColor].present? ? params[:backgroundColor] : existing_background_color
          new_bg = {
            'useImage' => true,
            'backgroundColor' => preserved_background_color
          }
        else
          # When useImage is false, expect color
          unless params[:backgroundColor].present?
            return error_response(
              message: 'Background color is required when useImage is false',
              status: :unprocessable_content
            )
          end

          # Update wrapper_background: useImage false, backgroundColor set
          new_bg = {
            'useImage' => false,
            'backgroundColor' => params[:backgroundColor]
          }
        end

        if @session.update(wrapper_background: new_bg)
          success_response(
            data: {
              wrapper_background: format_wrapper_background(@session)
            },
            message: 'Background updated successfully'
          )
        else
          error_response(
            message: 'Validation failed',
            errors: format_validation_errors(@session),
            status: :unprocessable_content
          )
        end
      end

      private

      def set_session
        @session = RouletteSession.find(params[:id])
      end

      def session_params
        params.permit(:title, :is_multiple, draw_styles: {}, wrapper_background: {})
      end

      def format_session_response(session)
        {
          id: session.id,
          user_id: session.user_id,
          title: session.title,
          logo_url: session.logo.attached? ? url_for(session.logo) : nil,
          draw_styles: session.draw_styles || {},
          wrapper_background: format_wrapper_background(session),
          is_multiple: session.is_multiple,
          created_at: session.created_at.iso8601,
          updated_at: session.updated_at.iso8601
        }
      end

      def format_wrapper_background(session)
        bg = session.wrapper_background || {}
        {
          'useImage' => bg['useImage'] || false,
          'backgroundImgUrl' => session.background_image.attached? ? url_for(session.background_image) : nil,
          'backgroundColor' => bg['backgroundColor']
        }
      end
    end
  end
end
