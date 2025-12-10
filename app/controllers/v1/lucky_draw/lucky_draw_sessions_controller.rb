module V1
  module LuckyDraw
    class LuckyDrawSessionsController < ApplicationController
      skip_before_action :authenticate_user!, only: [:serve_logo, :serve_background]
      skip_before_action :require_verified_email!, only: [:serve_logo, :serve_background]

      before_action :set_event, except: [:serve_logo, :serve_background]
      before_action :set_session, only: [:show, :update, :destroy, :background_manager]

      # GET /v1/events/:event_id/lucky_draw/sessions
      def index
        authorize @event, :show?

        @sessions = @event.lucky_draw_sessions.ordered

        success_response(
          data: @sessions.map { |s| format_session_response(s) },
          message: 'Success'
        )
      end

      # GET /v1/events/:event_id/lucky_draw/sessions/:id
      def show
        authorize @session
        success_response(
          data: format_session_response(@session),
          message: 'Success'
        )
      end

      # POST /v1/events/:event_id/lucky_draw/sessions
      def create
        @session = @event.lucky_draw_sessions.build(session_params)
        authorize @session

        if params[:logo].present?
          logo_path = store_session_logo(params[:logo])
          @session.logo = logo_path if logo_path
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

      # PATCH /v1/events/:event_id/lucky_draw/sessions/:id
      def update
        authorize @session

        if params[:remove_logo] == 'true' || params[:remove_logo] == true
          if @session.logo.present?
             old_path = Rails.root.join('storage', @session.logo)
             File.delete(old_path) if File.exist?(old_path)
          end
          @session.logo = nil
        elsif params[:logo].present?
          logo_path = store_session_logo(params[:logo])
          @session.logo = logo_path if logo_path
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

      # DELETE /v1/events/:event_id/lucky_draw/sessions/:id
      def destroy
        authorize @session
        @session.destroy
        success_response(
          message: 'Session deleted successfully'
        )
      end

      # GET /v1/events/:event_id/lucky_draw/sessions/:id/background-manager
      # POST /v1/events/:event_id/lucky_draw/sessions/:id/background-manager
      def background_manager
        authorize @session

        if request.get?
          # GET request - return current wrapper_background
          return success_response(
            data: {
              wrapper_background: @session.wrapper_background || {}
            },
            message: 'Success'
          )
        end

        # POST request - update wrapper_background
        use_image = ActiveModel::Type::Boolean.new.cast(params[:useImage]) || false

        # Preserve existing values from current wrapper_background
        current_bg = @session.wrapper_background || {}
        existing_background_color = current_bg['backgroundColor']
        existing_background_img_url = current_bg['backgroundImgUrl']

        if use_image
          # When useImage is true, either:
          # 1. A new image file is uploaded (params[:backgroundImage].present?)
          # 2. Or an existing image already exists (existing_background_img_url.present?)
          # Only require a new file if there's no existing image
          unless params[:backgroundImage].present? || existing_background_img_url.present?
            return error_response(
              message: 'Image file is required when useImage is true and no existing image is set',
              status: :unprocessable_content
            )
          end

          # If a new image is uploaded, store it
          # Otherwise, keep the existing image URL
          image_path = if params[:backgroundImage].present?
            stored_path = store_session_background(params[:backgroundImage])
            unless stored_path
              return error_response(
                message: 'Failed to store background image',
                status: :unprocessable_content
              )
            end
            stored_path
          else
            existing_background_img_url
          end

          # Update wrapper_background: useImage true, backgroundImgUrl set, preserve backgroundColor
          # Use provided backgroundColor if present (from form), otherwise use existing from database
          preserved_background_color = params[:backgroundColor].present? ? params[:backgroundColor] : existing_background_color
          new_bg = {
            'useImage' => true,
            'backgroundImgUrl' => image_path,
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

          # Update wrapper_background: useImage false, backgroundColor set, preserve backgroundImgUrl
          new_bg = {
            'useImage' => false,
            'backgroundColor' => params[:backgroundColor],
            'backgroundImgUrl' => existing_background_img_url
          }
        end

        if @session.update(wrapper_background: new_bg)
          success_response(
            data: {
              wrapper_background: @session.wrapper_background
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

      # GET /lucky_draw_session_logos/:filename
      def serve_logo
        filename = params[:filename]
        # Security check
        if filename.include?('..') || filename.include?('/') || filename.include?('\\')
          return head :bad_request
        end

        path = Rails.root.join('storage', 'lucky_draw_session_logos', filename)

        if File.exist?(path)
          send_file path, disposition: 'inline'
        else
          head :not_found
        end
      end

      # GET /lucky_draw_session_backgrounds/:filename
      def serve_background
        filename = params[:filename]
        # Security check
        if filename.include?('..') || filename.include?('/') || filename.include?('\\')
          return head :bad_request
        end

        path = Rails.root.join('storage', 'lucky_draw_session_backgrounds', filename)

        if File.exist?(path)
          send_file path, disposition: 'inline'
        else
          head :not_found
        end
      end

      private

      def set_event
        @event = Event.friendly.find(params[:event_id])
      end

      def set_session
        @session = @event.lucky_draw_sessions.find(params[:id])
      end

      def session_params
        params.permit(:title, :draw_date, :use_gifts, draw_styles: {}, wrapper_background: {})
      end

      def format_session_response(session)
        {
          id: session.id,
          event_id: session.event_id,
          title: session.title,
          draw_date: session.draw_date&.iso8601,
          logo: session.logo,
          draw_styles: session.draw_styles || {},
          wrapper_background: session.wrapper_background || {},
          use_gifts: session.use_gifts,
          created_at: session.created_at.iso8601,
          updated_at: session.updated_at.iso8601
        }
      end

      def store_session_logo(uploaded_file)
        images_dir = Rails.root.join('storage', 'lucky_draw_session_logos')
        FileUtils.mkdir_p(images_dir)

        timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
        extension = File.extname(uploaded_file.original_filename)
        filename = "session-#{timestamp}-#{SecureRandom.hex(4)}#{extension}"
        file_path = images_dir.join(filename)

        File.open(file_path, 'wb') do |file|
          file.write(uploaded_file.read)
        end

        "lucky_draw_session_logos/#{filename}"
      rescue StandardError => e
        Rails.logger.error "Failed to store session logo: #{e.message}"
        nil
      end

      def store_session_background(uploaded_file)
        images_dir = Rails.root.join('storage', 'lucky_draw_session_backgrounds')
        FileUtils.mkdir_p(images_dir)

        timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
        extension = File.extname(uploaded_file.original_filename)
        filename = "bg-#{timestamp}-#{SecureRandom.hex(4)}#{extension}"
        file_path = images_dir.join(filename)

        File.open(file_path, 'wb') do |file|
          file.write(uploaded_file.read)
        end

        "lucky_draw_session_backgrounds/#{filename}"
      rescue StandardError => e
        Rails.logger.error "Failed to store session background: #{e.message}"
        nil
      end
    end
  end
end
