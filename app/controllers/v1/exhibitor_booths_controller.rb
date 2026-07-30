# frozen_string_literal: true

module V1
  class ExhibitorBoothsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_event, only: %i[index create bulk]
    before_action :set_booth, only: %i[update destroy release]

    def index
      booths = policy_scope(@event.exhibitor_booths.includes(:exhibitor_booth_price, :exhibitor_kit))
      booths = booths.where(status: params[:status]) if params[:status].present?
      if params[:exhibitor_booth_price_id].present?
        booths = booths.where(exhibitor_booth_price_id: params[:exhibitor_booth_price_id])
      end
      if params[:exhibitor_zone_id].present?
        booths = booths.joins(:exhibitor_booth_price)
          .where(exhibitor_booth_prices: { exhibitor_zone_id: params[:exhibitor_zone_id] })
      end

      render json: booths.order(:number).map { |booth| serialize(booth) }
    end

    def create
      booth = @event.exhibitor_booths.new(booth_params)
      authorize booth

      if booth.save
        render json: serialize(booth), status: :created
      else
        render json: booth.errors, status: :unprocessable_content
      end
    end

    def bulk
      booths = bulk_numbers.map do |number|
        @event.exhibitor_booths.new(number: number,
          exhibitor_booth_price_id: bulk_params[:exhibitor_booth_price_id],
          status: bulk_params[:status].presence || :available)
      end
      booths.each { |booth| authorize booth, :create? }

      ExhibitorBooth.transaction { booths.each(&:save!) }
      render json: booths.map { |booth| serialize(booth) }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: e.record.errors, status: :unprocessable_content
    end

    def update
      authorize @booth

      if @booth.update(booth_params)
        render json: serialize(@booth)
      else
        render json: @booth.errors, status: :unprocessable_content
      end
    end

    def release
      authorize @booth, :update?

      ExhibitorBooth.transaction do
        kit = @booth.exhibitor_kit
        @booth.update!(status: :available, exhibitor_kit: nil)
        kit&.update!(booth_number: nil)
      end

      render json: serialize(@booth)
    end

    def destroy
      authorize @booth

      if @booth.available? || @booth.blocked?
        @booth.destroy
        head :no_content
      else
        render json: { errors: ['Cannot delete a booth that is reserved or booked'] },
          status: :unprocessable_content
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_booth
      @booth = ExhibitorBooth.find(params[:id])
    end

    def booth_params
      params.require(:exhibitor_booth).permit(:exhibitor_booth_price_id, :number, :status)
    end

    def bulk_params
      params.require(:exhibitor_booths).permit(:exhibitor_booth_price_id, :status, numbers: [])
    end

    def bulk_numbers
      bulk_params[:numbers].to_a.map { |number| number.to_s.strip }.compact_blank.uniq
    end

    def serialize(booth)
      {
        id: booth.id,
        number: booth.number,
        status: booth.status,
        exhibitor_booth_price_id: booth.exhibitor_booth_price_id,
        booth_type: booth.exhibitor_booth_price.booth_type,
        zone: booth.exhibitor_booth_price.zone,
        label: booth.exhibitor_booth_price.label,
        held_by: booth.exhibitor_kit&.company_name,
        held_since: booth.exhibitor_kit&.created_at
      }
    end
  end
end
