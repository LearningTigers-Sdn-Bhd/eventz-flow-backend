class ExhibitorBookingCapacity
  SoldOut = Class.new(StandardError)

  def self.lock!(booth_price, quantity:, excluding: nil)
    booth_price.exhibitor_zone&.lock!
    booth_price.lock!
    if booth_price.inventory?
      raise SoldOut if booth_price.bookable_booths.count < quantity

      return
    end

    consuming = ExhibitorKit.where(exhibitor_booth_price_id: booth_price.id).where.not(id: excluding&.id)
      .where('booking_status = ? OR (booking_status = ? AND (reservation_expires_at IS NULL OR reservation_expires_at > ?))',
        ExhibitorKit.booking_statuses[:paid], ExhibitorKit.booking_statuses[:active], Time.current)
      .sum(:booth_quantity)
    zone_consuming = if booth_price.exhibitor_zone
      ExhibitorKit.joins(:exhibitor_booth_price)
        .where(exhibitor_booth_prices: { exhibitor_zone_id: booth_price.exhibitor_zone_id })
        .where.not(id: excluding&.id)
        .where('booking_status = ? OR (booking_status = ? AND (reservation_expires_at IS NULL OR reservation_expires_at > ?))',
          ExhibitorKit.booking_statuses[:paid], ExhibitorKit.booking_statuses[:active], Time.current)
        .sum(:booth_quantity)
    else
      0
    end

    raise SoldOut if booth_price.quota && consuming + quantity > booth_price.quota
    raise SoldOut if booth_price.exhibitor_zone&.quota && zone_consuming + quantity > booth_price.exhibitor_zone.quota
  end
end
