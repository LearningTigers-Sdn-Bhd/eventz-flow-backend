module V1
  module Public
    class WishesController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def index
        event = wedding_event
        return unless event

        render json: { wishes: event.wishes.for_display.map { |wish| serialize_wish(wish) } }
      end

      def create
        event = wedding_event
        return unless event

        wish = event.wishes.new(
          wish_params.merge(visitor: visitor_for(event)).merge(initial_status_attributes(event))
        )

        if wish.save
          broadcast_new_wish(event, wish) if wish.approved?
          render json: { wish: serialize_wish(wish) }, status: :created
        else
          render json: { error: wish.errors.full_messages.to_sentence }, status: :unprocessable_content
        end
      end

      private

      def wedding_event
        event = Event.friendly.find(params[:slug])
        return event if event.use_wedding?

        render json: { error: 'Event not found' }, status: :not_found
        nil
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Event not found' }, status: :not_found
        nil
      end

      def visitor_for(event)
        return nil if params[:visitor_public_id].blank?

        event.visitors.find_by(public_id: params[:visitor_public_id])
      end

      def wish_params
        params.permit(:guest_name, :message)
      end

      def initial_status_attributes(event)
        return { status: :approved, approved_at: Time.current } if event.auto_approve_wishes?

        { status: :pending }
      end

      def broadcast_new_wish(event, wish)
        ActionCable.server.broadcast(
          "wishes_wall_event_#{event.id}",
          {
            type: 'new_wish',
            wish: {
              id: wish.id,
              guest_name: wish.guest_name,
              message: wish.message,
              approved_at: wish.approved_at&.iso8601,
              created_at: wish.created_at.iso8601,
              status: wish.status
            }
          }
        )
      end

      def serialize_wish(wish)
        {
          id: wish.id,
          guest_name: wish.guest_name,
          message: wish.message,
          status: wish.status,
          approved_at: wish.approved_at&.iso8601,
          created_at: wish.created_at.iso8601
        }
      end
    end
  end
end
