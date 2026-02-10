module V1
  module SeatTicketing
    class EventSeatGroupsController < ApplicationController
      include SeatTicketingContext
      before_action :set_section
      before_action :set_group, only: [:show, :update, :destroy, :assign_seats]

      def index
        render json: @section.event_seat_groups
      end

      def show
        render json: @group.as_json(include: :event_ticket_seats)
      end

      def create
        @group = @section.event_seat_groups.build(group_params)
        if @group.save
          render json: @group, status: :created
        else
          render json: { errors: @group.errors.full_messages }, status: :unprocessable_content
        end
      end

      def update
        if @group.update(group_params)
          render json: @group
        else
          render json: { errors: @group.errors.full_messages }, status: :unprocessable_content
        end
      end

      def destroy
        @group.destroy
        head :no_content
      end

      def assign_seats
        seat_ids = params[:seat_ids] || []
        
        ActiveRecord::Base.transaction do
          # Remove existing assignments for these seats
          EventSeatGroupAssignment.where(event_ticket_seat_id: seat_ids).destroy_all
          
          # Add new assignments
          seat_ids.each do |seat_id|
            @group.event_seat_group_assignments.create!(event_ticket_seat_id: seat_id)
          end
        end

        render json: @group.as_json(include: :event_ticket_seats)
      rescue ActiveRecord::RecordInvalid => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      private

      def set_section
        load_seat_session
        load_seat_venue
        load_seat_section(param_key: :section_id)
      end

      def set_group
        @group = @section.event_seat_groups.find(params[:id])
      end

      def group_params
        params.require(:group).permit(:name, :extra_price)
      end
    end
  end
end
