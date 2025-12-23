# app/controllers/v1/business_matching/hosts_controller.rb
module V1
  module BusinessMatching
    class HostsController < ApplicationController
      skip_before_action :authenticate_user!, only: [:index, :show_availability]
      skip_before_action :require_verified_email!, only: [:index, :show_availability]

      # GET /v1/events/:event_id/business_matching/hosts
      def index
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        # Fetch assignments directly to ensure we get the session ID reliably
        assignments = BusinessHostAssignment.where(event_id: event.id).includes(:user)

        # Serialize
        render json: assignments.map { |assignment|
          user = assignment.user
          {
            id: user.id,
            full_name: user.full_name,
            email: user.email,
            phone: user.phone,
            business_matching_event_id: assignment.business_matching_event_id
          }
        }, status: :ok
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      # POST /v1/business_matching/events/:event_id/hosts/join
      def join
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        bm_event_id = params[:business_matching_event_id]
        return render json: { error: 'Business Matching Event ID is required' }, status: :bad_request unless bm_event_id.present?

        ActiveRecord::Base.transaction do
          # 1. Ensure general event access via EventAssignment
          EventAssignment.find_or_create_by!(
            user: current_user,
            event: event,
            role: :business_host
          )

          # 2. Create the specific session assignment
          BusinessHostAssignment.find_or_create_by!(
            user: current_user,
            event: event,
            business_matching_event_id: bm_event_id
          )
        end

        update_event_cache(event, bm_event_id, current_user)
        ActionCable.server.broadcast("business_matching_event_#{event.id}", { action: "hosts_updated" })

        render json: { message: "Successfully joined as a business host for #{event.title}" }, status: :ok
      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      # POST /v1/business_matching/events/:event_id/hosts/create_and_assign
      def create_and_assign
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :manage_business_hosts? # Assuming a Pundit policy

        bm_event_id = params[:business_matching_event_id]
        return render json: { error: 'Business Matching Event ID is required' }, status: :bad_request unless bm_event_id.present?

        new_host = nil

        ActiveRecord::Base.transaction do
          # 1. Create the user; password is set via host_params
          new_host = User.new(host_params)
          new_host.email_verified_at = Time.current # Pre-verify email
          new_host.save!

          # 2. Ensure general event access via EventAssignment
          EventAssignment.find_or_create_by!(
            user_id: new_host.id,
            event_id: event.id,
            role: :business_host
          )

          # 3. Create the specific session assignment
          BusinessHostAssignment.create!(
            user_id: new_host.id,
            event_id: event.id,
            business_matching_event_id: bm_event_id
          )
        end

        update_event_cache(event, bm_event_id, new_host)
        ActionCable.server.broadcast("business_matching_event_#{event.id}", { action: "hosts_updated" })

        render json: {
          id: new_host.id,
          full_name: new_host.full_name,
          email: new_host.email,
          phone: new_host.phone
        }, status: :created

      rescue ActiveRecord::RecordInvalid => e
        render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
      rescue Pundit::NotAuthorizedError
        render json: { error: "You are not authorized to perform this action." }, status: :forbidden
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      # DELETE /v1/business_matching/events/:event_id/hosts/remove
      def remove
        event = Event.find_by(id: params[:event_id])
        return render json: { error: 'Event not found' }, status: :not_found unless event

        authorize event, :manage_business_hosts?

        bm_event_id = params[:business_matching_event_id]
        return render json: { error: 'Business Matching Event ID is required' }, status: :bad_request unless bm_event_id.present?

        assignment = BusinessHostAssignment.find_by(
          event_id: event.id,
          business_matching_event_id: bm_event_id
        )

        if assignment
          user_id = assignment.user_id
          ActiveRecord::Base.transaction do
            assignment.destroy
            
            # Check if user has any other session assignments left for this event
            remaining = BusinessHostAssignment.exists?(user_id: user_id, event_id: event.id)
            unless remaining
                # Remove general event access if no sessions are left
                EventAssignment.where(user_id: user_id, event_id: event.id, role: :business_host).destroy_all
            end
          end
          update_event_cache(event, bm_event_id, nil)
          ActionCable.server.broadcast("business_matching_event_#{event.id}", { action: "hosts_updated" })
          render json: { message: "Host removed successfully" }, status: :ok
        else
          render json: { error: "Host assignment not found" }, status: :not_found
        end
      end

      # GET /v1/events/:event_id/business_matching/hosts/:host_user_id/availability
      def show_availability
        event = Event.find_by(id: params[:event_id])
        host = User.find_by(id: params[:host_user_id])
        
        return render json: { error: 'Event not found' }, status: :not_found unless event
        return render json: { error: 'Business host not found' }, status: :not_found unless host

        unless host.is_business_host?(event)
          return render json: { error: 'User is not a business host for this event' }, status: :forbidden
        end

        service_result = BusinessMatchingService.new(current_user).fetch_host_availability(
          event.id,
          host.id,
          force_refresh: params[:force_refresh] == 'true'
        )

        if service_result.success?
          render json: service_result.data, status: :ok
        else
          render json: { errors: service_result.errors }, status: service_result.status || :internal_server_error
        end
      rescue StandardError => e
        render json: { errors: e.message }, status: :internal_server_error
      end

      private

      def update_event_cache(event, bm_event_id, host_user)
        cache_key = "business_matching_events_#{event.id}"
        events = Rails.cache.read(cache_key)
        
        if events.is_a?(Array)
          events.map! do |e|
            # Match using string comparison for safety
            if e[:id].to_s == bm_event_id.to_s || (e["id"] && e["id"].to_s == bm_event_id.to_s)
               # Construct host object or nil
               host_data = if host_user
                             {
                               id: host_user.id,
                               full_name: host_user.full_name,
                               email: host_user.email,
                               phone: host_user.phone
                             }
                           else
                             nil
                           end
               
               # Handle both symbol and string keys for the event hash
               if e.key?(:host)
                 e[:host] = host_data
               else
                 e["host"] = host_data
               end
            end
            e
          end
          Rails.cache.write(cache_key, events, expires_in: 1.hour)
        end
      end

      def host_params
        params.require(:host).permit(:full_name, :email, :phone, :password)
      end
    end
  end
end
