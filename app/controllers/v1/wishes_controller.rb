module V1
  class WishesController < ApplicationController
    before_action :set_event
    before_action :require_wedding_event
    before_action :set_wish, only: %i[approve reject destroy]

    def index
      authorize @event, :show?

      wishes = @event.wishes
      wishes = wishes.where(status: params[:status]) if params[:status].present?

      pagy, records = pagy(wishes.order(created_at: :desc))

      render json: {
        wishes: records.map { |wish| serialize_wish(wish) },
        pagination: pagy_metadata(pagy)
      }
    end

    def approve
      authorize @wish

      @wish.update!(status: :approved, approved_at: Time.current)

      ActionCable.server.broadcast(
        "wishes_wall_event_#{@event.id}",
        {
          type: 'new_wish',
          wish: {
            id: @wish.id,
            guest_name: @wish.guest_name,
            message: @wish.message,
            approved_at: @wish.approved_at.iso8601
          }
        }
      )

      render json: { wish: serialize_wish(@wish) }
    end

    def reject
      authorize @wish

      @wish.update!(status: :rejected)

      render json: { wish: serialize_wish(@wish) }
    end

    def destroy
      authorize @wish

      was_approved = @wish.approved?
      wish_id = @wish.id

      @wish.destroy!

      if was_approved
        ActionCable.server.broadcast(
          "wishes_wall_event_#{@event.id}",
          { type: 'remove_wish', wish_id: wish_id }
        )
      end

      render json: { message: 'Wish deleted' }
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def require_wedding_event
      return if @event.use_wedding?

      render json: { error: 'Event not found' }, status: :not_found
    end

    def set_wish
      @wish = @event.wishes.find(params[:id])
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
