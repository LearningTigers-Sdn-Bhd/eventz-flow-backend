class TicketDayIndexResolver
  TIME_ZONE = 'Asia/Kuala_Lumpur'.freeze

  def self.current_day_index(event, now: Time.current)
    return nil unless event&.start_date.present? && event&.end_date.present?

    today = now.in_time_zone(TIME_ZONE).to_date
    start_date = event.start_date.to_date
    end_date = event.end_date.to_date

    return nil if today < start_date || today > end_date

    (today - start_date).to_i + 1
  end
end
