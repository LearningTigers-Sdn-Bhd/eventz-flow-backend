# frozen_string_literal: true

class BusinessMatchingService < BaseService
  def fetch_events(event_id, force_refresh: false)
    event = Event.find_by(id: event_id)
    sessions = BusinessMatchingSession.where(event_id: event_id, is_active: true)
    host_assignments = BusinessHostAssignment.where(event_id: event_id).includes(:user)
    
    host_lookup = host_assignments.each_with_object({}) do |assignment, memo|
      if assignment.business_matching_event_id.present? && assignment.user.present?
        memo[assignment.business_matching_event_id.to_s] = assignment.user
      end
    end

    host_users = host_assignments.map(&:user).compact
    participants = BusinessMatchingParticipant.where(
      event_id: event_id,
      registerable_type: 'User',
      registerable_id: host_users.map(&:id)
    )
    participant_lookup = participants.each_with_object({}) do |p, memo|
      memo[p.registerable_id] = p
    end

    booking_counts = BusinessMatchingBooking.where(business_matching_session_id: sessions.pluck(:id))
                                             .where.not(status: 'Cancelled')
                                             .group(:business_matching_session_id)
                                             .count

    data = sessions.map do |session|
      host_user = host_lookup[session.id.to_s]
      h_profile = host_user ? participant_lookup[host_user.id] : nil
      offering_tags = h_profile&.offering_tags.presence || event&.business_matching_offering_tags || []
      interest_tags = h_profile&.interest_tags.presence || event&.business_matching_interest_tags || []

      {
        id: session.id.to_s,
        event_id: event_id.to_s,
        title: session.title,
        duration: session.slot_duration,
        location: session.location,
        admin_email: session.admin_email,
        admin_wa_number: session.admin_wa_number,
        start_date: session.start_date,
        end_date: session.end_date,
        offering_tags: offering_tags,
        interest_tags: interest_tags,
        created_at: session.created_at.iso8601,
        updated_at: session.updated_at.iso8601,
        bookings_count: booking_counts[session.id] || 0,
        host: host_user ? {
          id: host_user.id,
          full_name: host_user.full_name,
          email: host_user.email,
          phone: host_user.phone,
          offering_tags: offering_tags,
          interest_tags: interest_tags,
          description: h_profile&.profile_data&.[]('description').presence || "Professional host available for business matchmaking, partnerships, and collaborations.",
          sourcing_intent: h_profile&.profile_data&.[]('sourcing_intent').presence || "Looking for strategic partnerships and business development opportunities.",
          capabilities: h_profile&.profile_data&.[]('capabilities').presence || "Expertise in technology solutions, sales growth, and project execution."
        } : nil
      }
    end

    BaseService::ServiceResult.new(success: true, data: data)
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_availability(bm_event_id, event_id, force_refresh: false)
    session = BusinessMatchingSession.find_by(id: bm_event_id)
    return BaseService::ServiceResult.new(success: false, errors: "Session not found", status: :not_found) unless session

    assignment = BusinessHostAssignment.find_by(event_id: event_id, business_matching_event_id: bm_event_id.to_s)
    host_user_id = assignment&.user_id

    availabilities = if host_user_id
                       BusinessMatchingAvailability.where(business_matching_session_id: session.id, host_user_id: host_user_id)
                     else
                       BusinessMatchingAvailability.none
                     end

    if availabilities.empty?
      availabilities = BusinessMatchingAvailability.where(business_matching_session_id: session.id, host_user_id: nil)
    end

    availabilities_by_day = {}
    if availabilities.present?
      availabilities.each do |av|
        availabilities_by_day[av.day] ||= []
        availabilities_by_day[av.day] << av
      end
    else
      start_date = session.start_date || session.event.start_date&.to_date || Time.zone.today
      end_date = session.end_date || session.event.end_date&.to_date || start_date
      (start_date..end_date).each do |day|
        availabilities_by_day[day] = [
          BusinessMatchingAvailability.new(
            business_matching_session_id: session.id,
            day: day,
            start_time: session.start_time || "09:00",
            end_time: session.end_time || "17:00"
          )
        ]
      end
    end

    formatted_dates = []
    availabilities_by_day.each do |day, avs|
      all_slots = []
      avs.each do |av|
        all_slots.concat(_generate_slots_for_availability(av, session))
      end
      all_slots.uniq!

      booked_times = if host_user_id
                       BusinessMatchingBooking.where(
                         host_user_id: host_user_id,
                         booking_date: day
                       ).where.not(status: "Cancelled").pluck(:booking_time)
                     else
                       BusinessMatchingBooking.where(
                         business_matching_session_id: session.id,
                         booking_date: day
                       ).where.not(status: "Cancelled").pluck(:booking_time)
                     end

      available_slots = all_slots.reject { |slot_time| booked_times.include?(slot_time) }

      formatted_dates << {
        day: day.strftime("%A"),
        date: day.strftime("%-d %B %Y"),
        slots: available_slots.size
      }
    end

    formatted_dates.sort_by! { |d| Date.parse(d[:date]) }

    BaseService::ServiceResult.new(success: true, data: { dates: formatted_dates })
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_host_availability(event_id, host_user_id, force_refresh: false)
    assignment = BusinessHostAssignment.find_by(event_id: event_id, user_id: host_user_id)
    unless assignment
      return BaseService::ServiceResult.new(success: false, errors: "Host assignment not found", status: :not_found)
    end

    bm_event_id = assignment.business_matching_event_id
    session = BusinessMatchingSession.find_by(id: bm_event_id)
    unless session
      return BaseService::ServiceResult.new(success: false, errors: "Session not found", status: :not_found)
    end

    availabilities = BusinessMatchingAvailability.where(business_matching_session_id: session.id, host_user_id: host_user_id)
    if availabilities.empty?
      availabilities = BusinessMatchingAvailability.where(business_matching_session_id: session.id, host_user_id: nil)
    end

    availabilities_by_day = {}
    if availabilities.present?
      availabilities.each do |av|
        availabilities_by_day[av.day] ||= []
        availabilities_by_day[av.day] << av
      end
    else
      start_date = session.start_date || session.event.start_date&.to_date || Time.zone.today
      end_date = session.end_date || session.event.end_date&.to_date || start_date
      (start_date..end_date).each do |day|
        availabilities_by_day[day] = [
          BusinessMatchingAvailability.new(
            business_matching_session_id: session.id,
            day: day,
            start_time: session.start_time || "09:00",
            end_time: session.end_time || "17:00"
          )
        ]
      end
    end

    formatted_dates = []
    availabilities_by_day.each do |day, avs|
      all_slots = []
      avs.each do |av|
        all_slots.concat(_generate_slots_for_availability(av, session))
      end
      all_slots.uniq!

      booked_times = BusinessMatchingBooking.where(
                       host_user_id: host_user_id,
                       booking_date: day
                     ).where.not(status: "Cancelled").pluck(:booking_time)

      available_slots = all_slots.reject { |slot_time| booked_times.include?(slot_time) }

      formatted_dates << {
        day: day.strftime("%A"),
        date: day.strftime("%-d %B %Y"),
        slots: available_slots.size
      }
    end

    formatted_dates.sort_by! { |d| Date.parse(d[:date]) }

    BaseService::ServiceResult.new(success: true, data: { dates: formatted_dates })
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_detailed_slots(bm_event_id, date, event_id, force_refresh: false)
    session = BusinessMatchingSession.find_by(id: bm_event_id)
    return BaseService::ServiceResult.new(success: false, errors: "Session not found", status: :not_found) unless session

    parsed_date = Date.parse(date) rescue Time.zone.today

    assignment = BusinessHostAssignment.find_by(event_id: event_id, business_matching_event_id: bm_event_id.to_s)
    host_user_id = assignment&.user_id

    availabilities = if host_user_id
                       BusinessMatchingAvailability.where(business_matching_session_id: session.id, host_user_id: host_user_id, day: parsed_date)
                     else
                       BusinessMatchingAvailability.none
                     end

    if availabilities.empty?
      availabilities = BusinessMatchingAvailability.where(business_matching_session_id: session.id, host_user_id: nil, day: parsed_date)
    end

    if availabilities.empty?
      availabilities = [
        BusinessMatchingAvailability.new(
          business_matching_session_id: session.id,
          day: parsed_date,
          start_time: session.start_time || "09:00",
          end_time: session.end_time || "17:00"
        )
      ]
    end

    all_slots = []
    availabilities.each do |av|
      all_slots.concat(_generate_slots_for_availability(av, session))
    end
    all_slots.uniq!

    booked_times = if host_user_id
                     BusinessMatchingBooking.where(
                       host_user_id: host_user_id,
                       booking_date: parsed_date
                     ).where.not(status: "Cancelled").pluck(:booking_time)
                   else
                     BusinessMatchingBooking.where(
                       business_matching_session_id: session.id,
                       booking_date: parsed_date
                     ).where.not(status: "Cancelled").pluck(:booking_time)
                   end

    available_slots = all_slots.reject { |slot_time| booked_times.include?(slot_time) }

    slots_data = available_slots.map do |slot_time|
      {
        slot: slot_time,
        date: date
      }
    end

    BaseService::ServiceResult.new(success: true, data: { slots: slots_data })
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_bookings(bm_event_id, event_id, force_refresh: false)
    session = BusinessMatchingSession.find_by(id: bm_event_id)
    return BaseService::ServiceResult.new(success: false, errors: "Session not found", status: :not_found) unless session

    bookings = BusinessMatchingBooking.where(business_matching_session_id: session.id).includes(:host_user)

    event = Event.find_by(id: event_id)
    if event.present? && user&.is_business_host?(event) && !user&.is_org_owner_or_organizer?
      bookings = bookings.where(host_user_id: user.id)
    end

    formatted_bookings = _transform_local_bookings(bookings, session)

    BaseService::ServiceResult.new(success: true, data: { bookings: formatted_bookings })
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def create_booking(bm_event_id, event_id, booking_params)
    session = BusinessMatchingSession.find_by(id: bm_event_id)
    return BaseService::ServiceResult.new(success: false, errors: "Session not found", status: :not_found) unless session

    assignment = BusinessHostAssignment.find_by(event_id: event_id, business_matching_event_id: bm_event_id.to_s)
    host_user_id = assignment&.user_id
    return BaseService::ServiceResult.new(success: false, errors: "No host assigned to this session", status: :unprocessable_entity) unless host_user_id

    booking = BusinessMatchingBooking.new(
      business_matching_session: session,
      host_user_id: host_user_id,
      name: booking_params[:name],
      email: booking_params[:email],
      phone: booking_params[:phone],
      booking_date: Date.parse(booking_params[:date]),
      booking_time: booking_params[:time],
      duration: session.slot_duration,
      status: "Confirmed",
      payment_status: "Pending"
    )

    if booking.save
      ActionCable.server.broadcast("business_matching_event_#{event_id}", { action: "booking_created" })
      
      transformed = _transform_local_bookings([booking], session).first
      BaseService::ServiceResult.new(success: true, data: transformed)
    else
      BaseService::ServiceResult.new(success: false, errors: booking.errors.full_messages.join(', '), status: :unprocessable_entity)
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def public_create_booking(bm_event_id, event_id, host_user_id, booking_params)
    session = BusinessMatchingSession.find_by(id: bm_event_id)
    return BaseService::ServiceResult.new(success: false, errors: "Session not found", status: :not_found) unless session

    target_host_id = host_user_id.presence
    unless target_host_id
      assignment = BusinessHostAssignment.find_by(event_id: event_id, business_matching_event_id: bm_event_id.to_s)
      target_host_id = assignment&.user_id
    end
    return BaseService::ServiceResult.new(success: false, errors: "No host assigned", status: :unprocessable_entity) unless target_host_id

    booking = BusinessMatchingBooking.new(
      business_matching_session: session,
      host_user_id: target_host_id,
      name: booking_params[:name],
      email: booking_params[:email],
      phone: booking_params[:phone],
      booking_date: Date.parse(booking_params[:date]),
      booking_time: booking_params[:time],
      duration: session.slot_duration,
      status: "Approved",
      payment_status: "Pending",
      host_comment: booking_params[:note]
    )

    if booking.save
      ActionCable.server.broadcast("business_matching_event_#{event_id}", { action: "booking_created" })

      transformed = _transform_local_bookings([booking], session).first

      begin
        EmailDelivery::AuditedDelivery.deliver_now(
          mailer_name: 'BookingMailer',
          mailer_action: 'confirmation_email',
          args: [transformed.with_indifferent_access, session.title, event_id],
          related: nil,
          metadata: { event_id: event_id, booking_id: booking.id.to_s }
        )
      rescue => e
        Rails.logger.error "Failed to send booking confirmation email: #{e.message}"
      end

      BaseService::ServiceResult.new(success: true, data: transformed)
    else
      BaseService::ServiceResult.new(success: false, errors: booking.errors.full_messages.join(', '), status: :unprocessable_entity)
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def update_booking(bm_event_id, event_id, booking_id, booking_params, host_user_id: nil)
    booking = BusinessMatchingBooking.find_by(id: booking_id)
    return BaseService::ServiceResult.new(success: false, errors: "Booking not found", status: :not_found) unless booking

    session = booking.business_matching_session

    updates = {}
    updates[:name] = booking_params[:name] if booking_params.key?(:name)
    updates[:email] = booking_params[:email] if booking_params.key?(:email)
    updates[:phone] = booking_params[:phone] if booking_params.key?(:phone)
    updates[:booking_date] = Date.parse(booking_params[:booking_date]) if booking_params[:booking_date].present?
    updates[:booking_time] = booking_params[:booking_time] if booking_params.key?(:booking_time)
    updates[:status] = booking_params[:status] if booking_params.key?(:status)
    updates[:payment_status] = booking_params[:payment_status] if booking_params.key?(:payment_status)
    updates[:attendance] = booking_params[:attendance] if booking_params.key?(:attendance)
    updates[:host_comment] = booking_params[:host_comment] if booking_params.key?(:host_comment)
    updates[:potential_deal_value] = booking_params[:potential_deal_value] if booking_params.key?(:potential_deal_value)
    updates[:host_user_id] = host_user_id if host_user_id.present?

    if booking.update(updates)
      ActionCable.server.broadcast("business_matching_event_#{event_id}", { action: "booking_updated" })
      
      transformed = _transform_local_bookings([booking], session).first
      BaseService::ServiceResult.new(success: true, data: transformed)
    else
      BaseService::ServiceResult.new(success: false, errors: booking.errors.full_messages.join(', '), status: :unprocessable_entity)
    end
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_single_booking(bm_event_id, event_id, booking_id)
    booking = BusinessMatchingBooking.find_by(id: booking_id)
    return BaseService::ServiceResult.new(success: false, errors: "Booking not found", status: :not_found) unless booking

    transformed = _transform_local_bookings([booking]).first
    BaseService::ServiceResult.new(success: true, data: transformed)
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def fetch_all_bookings(event_id, force_refresh: false)
    sessions = BusinessMatchingSession.where(event_id: event_id)
    bookings = BusinessMatchingBooking.where(business_matching_session_id: sessions.pluck(:id)).includes(:host_user, :business_matching_session)

    event = Event.find_by(id: event_id)
    if event.present? && user&.is_business_host?(event) && !user&.is_org_owner_or_organizer?
      bookings = bookings.where(host_user_id: user.id)
    end

    formatted_bookings = _transform_local_bookings(bookings)
    BaseService::ServiceResult.new(success: true, data: { bookings: formatted_bookings })
  rescue StandardError => e
    BaseService::ServiceResult.new(success: false, errors: e.message, status: :internal_server_error)
  end

  def transform_events(raw_events, event_id)
    event = Event.find_by(id: event_id)
    host_assignments = BusinessHostAssignment.where(event_id: event_id).includes(:user)
    
    host_lookup = host_assignments.each_with_object({}) do |assignment, memo|
      if assignment.business_matching_event_id.present? && assignment.user.present?
        memo[assignment.business_matching_event_id.to_s] = assignment.user
      end
    end

    host_users = host_assignments.map(&:user).compact
    participants = BusinessMatchingParticipant.where(
      event_id: event_id,
      registerable_type: 'User',
      registerable_id: host_users.map(&:id)
    )
    participant_lookup = participants.each_with_object({}) do |p, memo|
      memo[p.registerable_id] = p
    end

    booking_counts = BusinessMatchingBooking.where(business_matching_session_id: raw_events.map { |e| e["id"] || e["_id"] }.compact)
                                             .where.not(status: 'Cancelled')
                                             .group(:business_matching_session_id)
                                             .count

    raw_events.map do |event_data|
      bm_event_id = event_data["id"] || event_data["_id"]
      host_user = host_lookup[bm_event_id.to_s]
      h_profile = host_user ? participant_lookup[host_user.id] : nil
      offering_tags = h_profile&.offering_tags.presence || event&.business_matching_offering_tags || []
      interest_tags = h_profile&.interest_tags.presence || event&.business_matching_interest_tags || []

      {
        id: bm_event_id.to_s,
        event_id: event_id.to_s,
        title: event_data["title"],
        duration: event_data["slotDuration"],
        location: event_data["locationLink"],
        admin_email: event_data["adminEmail"],
        admin_wa_number: event_data["adminWaNumber"],
        offering_tags: offering_tags,
        interest_tags: interest_tags,
        created_at: event_data["createdAt"] || event_data["created_at"] || Time.current.iso8601,
        updated_at: event_data["updatedAt"] || event_data["updated_at"] || Time.current.iso8601,
        bookings_count: booking_counts[bm_event_id.to_s] || booking_counts[bm_event_id.to_i] || 0,
        host: host_user ? {
          id: host_user.id,
          full_name: host_user.full_name,
          email: host_user.email,
          phone: host_user.phone,
          offering_tags: offering_tags,
          interest_tags: interest_tags,
          description: h_profile&.profile_data&.[]('description').presence || "Professional host available for business matchmaking, partnerships, and collaborations.",
          sourcing_intent: h_profile&.profile_data&.[]('sourcing_intent').presence || "Looking for strategic partnerships and business development opportunities.",
          capabilities: h_profile&.profile_data&.[]('capabilities').presence || "Expertise in technology solutions, sales growth, and project execution."
        } : nil
      }
    end
  end

  def fetch_host_profile(event_id)
    participant = BusinessMatchingParticipant.find_or_initialize_by(
      event_id: event_id,
      registerable_type: 'User',
      registerable_id: user.id
    )

    BaseService::ServiceResult.new(success: true, data: {
      offering_tags: participant.offering_tags || [],
      interest_tags: participant.interest_tags || [],
      description: participant.profile_data&.[]('description') || "",
      sourcing_intent: participant.profile_data&.[]('sourcing_intent') || "",
      capabilities: participant.profile_data&.[]('capabilities') || ""
    })
  end

  def update_host_profile(event_id, profile_params)
    participant = BusinessMatchingParticipant.find_or_initialize_by(
      event_id: event_id,
      registerable_type: 'User',
      registerable_id: user.id
    )

    participant.profile_data ||= {}
    participant.profile_data['description'] = profile_params[:description] if profile_params.key?(:description)
    participant.profile_data['sourcing_intent'] = profile_params[:sourcing_intent] if profile_params.key?(:sourcing_intent)
    participant.profile_data['capabilities'] = profile_params[:capabilities] if profile_params.key?(:capabilities)

    if profile_params.key?(:interest_tags)
      participant.interest_tags = Array(profile_params[:interest_tags]).reject(&:blank?)
    end
    if profile_params.key?(:offering_tags)
      participant.offering_tags = Array(profile_params[:offering_tags]).reject(&:blank?)
    end

    if participant.save
      BaseService::ServiceResult.new(success: true, data: {
        offering_tags: participant.offering_tags,
        interest_tags: participant.interest_tags,
        description: participant.profile_data['description'],
        sourcing_intent: participant.profile_data['sourcing_intent'],
        capabilities: participant.profile_data['capabilities']
      })
    else
      BaseService::ServiceResult.new(success: false, errors: participant.errors.full_messages, status: :unprocessable_entity)
    end
  end

  private

  def _generate_slots_for_availability(availability, session)
    start_parts = availability.start_time.split(':').map(&:to_i)
    end_parts = availability.end_time.split(':').map(&:to_i)
    
    start_minutes = start_parts[0] * 60 + start_parts[1]
    end_minutes = end_parts[0] * 60 + end_parts[1]
    duration = session.slot_duration
    
    slots = []
    current_minutes = start_minutes
    while current_minutes + duration <= end_minutes
      hour = current_minutes / 60
      min = current_minutes % 60
      
      time_obj = Time.zone.parse("#{availability.day} #{format('%02d:%02d', hour, min)}")
      slots << time_obj.strftime("%I:%M %p")
      
      current_minutes += duration
    end
    slots
  end

  def _transform_local_bookings(bookings, session = nil)
    bookings.map do |b|
      sess = session || b.business_matching_session
      formatted_date = b.booking_date.strftime("%-d %B %Y")
      
      {
        id: b.id.to_s,
        name: b.name,
        email: b.email,
        phone: b.phone,
        date: formatted_date,
        booking_date: formatted_date,
        time: b.booking_time,
        booking_time: b.booking_time,
        duration: b.duration,
        status: b.status,
        event_title: sess&.title || "Matchmaking Session",
        location: sess&.location || "",
        cancel_link: "/event/#{sess&.event_id}/booking/#{b.id}/cancel",
        reschedule_link: "/event/#{sess&.event_id}/booking/#{b.id}/reschedule",
        meeting_approval_link: "/event/#{sess&.event_id}/booking/#{b.id}/approve",
        payment_status: b.payment_status,
        created_at: b.created_at.iso8601,
        attendance: b.attendance || "",
        host_comment: b.host_comment || "",
        potential_deal_value: b.potential_deal_value.to_f,
        host_user_id: b.host_user_id.to_s
      }
    end
  end
end
