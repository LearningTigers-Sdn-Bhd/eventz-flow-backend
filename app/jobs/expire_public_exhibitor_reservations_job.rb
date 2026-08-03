class ExpirePublicExhibitorReservationsJob < ApplicationJob
  queue_as :default

  def perform
    ExhibitorKit.where(booking_status: :active, payment_status: :unpaid)
      .where(reservation_expires_at: ..Time.current).find_each do |kit|
      kit.with_lock do
        payment = kit.exhibitor_registration_payment
        payment&.lock!
        if kit.booking_active? && kit.unpaid? && kit.reservation_expires_at&.past?
          next if payment&.gateway_order_id.present? && payment.order_expires_at&.future?

          kit.update!(booking_status: :expired)
        end
      end
    end
  end
end
