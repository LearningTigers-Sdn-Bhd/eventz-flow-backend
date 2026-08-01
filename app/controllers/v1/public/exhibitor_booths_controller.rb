# frozen_string_literal: true

module V1
  module Public
    class ExhibitorBoothsController < ApplicationController
      skip_before_action :authenticate_user!
      skip_before_action :require_verified_email!

      def index
        event = Event.friendly.find(params[:event_slug])
        booth_price = event.exhibitor_booth_prices.find(params[:exhibitor_booth_price_id])
        booths = booth_price.bookable_booths.order(:number)

        render json: { success: true,
                       data: booths.map { |booth| { id: booth.id, number: booth.number } } }
      end
    end
  end
end
