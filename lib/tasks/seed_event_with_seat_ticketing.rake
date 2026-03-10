# lib/tasks/seed_event_with_seat_ticketing.rake
namespace :db do
  namespace :seed do
    desc "Seed seat ticketing events and occupancy"
    task event_with_seat_ticketing: :environment do
      puts "\n" + "=" * 80
      puts "OPTIMIZED SEAT TICKETING SEEDING"
      puts "=" * 80

      if (Rails.env.production? || Rails.env.staging?) && ENV['ALLOW_SEAT_TICKETING_SEED'] != 'true'
        puts "\n🚫 ERROR: Seat ticketing seeding is DISABLED in production/staging!"
        exit(1)
      end

      # --- Helpers ---

      def wipe_event_data(event)
        return unless event
        puts "Wiping existing data for: #{event.title}..."
        
        # Unlink tickets and visitors from seats first
        EventTicketSeat.joins(event_seat_section: { event_seat_venue: :event_seat_session })
                       .where(event_seat_sessions: { event_id: event.id })
                       .update_all(ticket_id: nil, visitor_id: nil)

        event.tickets.destroy_all
        event.event_seat_sessions.destroy_all
        event.ticket_types.where.not(seat_ticketing_type: nil).destroy_all
      end

      def bulk_insert_seats(section, row_blocks:, col_blocks:, empty_blocks: [])
        seat_data = []
        current_r = 1
        
        row_blocks.each_with_index do |r_size, r_block_idx|
          (0...r_size).each do |r_offset|
            r = current_r + r_offset
            row_letter = ("A".ord + (current_r - 1 - r_block_idx + r_offset)).chr

            current_c = 1
            col_blocks.each_with_index do |c_size, c_block_idx|
              (0...c_size).each do |c_offset|
                c = current_c + c_offset
                next if empty_blocks.include?([r_block_idx, c_block_idx])

                c_idx = current_c - c_block_idx + c_offset
                seat_data << {
                  event_seat_section_id: section.id,
                  name: "#{section.name} #{row_letter}#{c_idx}",
                  extra_price: 0,
                  row_set: r,
                  col_set: c,
                  ticket_type_id: section.ticket_type_id,
                  created_at: Time.current,
                  updated_at: Time.current
                }
              end
              current_c += c_size + 1
            end
          end
          current_r += r_size + 1
        end

        EventTicketSeat.insert_all!(seat_data) if seat_data.any?
      end

      def seed_occupancy(event, session, ratio)
        seats = EventTicketSeat.joins(event_seat_section: { event_seat_venue: :event_seat_session })
                               .where(event_seat_sessions: { id: session.id })
        
        total = seats.count
        target = (total * ratio).round
        return if target == 0

        to_occupy = seats.shuffle.first(target)
        
        if event.use_ticket?
          ticket_data = to_occupy.map do |seat|
            {
              event_id: event.id,
              ticket_type_id: seat.ticket_type_id,
              attendee_name: "Seat Holder #{seat.id}",
              attendee_email: "seat-#{seat.id}@example.com",
              status: :purchased,
              payment_status: :paid,
              created_at: Time.current,
              updated_at: Time.current,
              public_id: SecureRandom.uuid
            }
          end
          
          result = Ticket.insert_all!(ticket_data, returning: [:id])
          ticket_ids = result.map { |r| r['id'] }
          
          to_occupy.each_with_index do |seat, idx|
            seat.update_columns(ticket_id: ticket_ids[idx])
          end
        else
          visitor_data = to_occupy.map do |seat|
            {
              event_id: event.id,
              full_name: "Visitor #{seat.id}",
              email: "visitor-#{seat.id}@example.com",
              public_id: SecureRandom.uuid,
              created_at: Time.current,
              updated_at: Time.current
            }
          end
          result = Visitor.insert_all!(visitor_data, returning: [:id])
          visitor_ids = result.map { |r| r['id'] }
          
          to_occupy.each_with_index do |seat, idx|
            seat.update_columns(visitor_id: visitor_ids[idx])
          end
        end
        
        puts "  ✓ Occupied #{target}/#{total} seats (#{ (ratio * 100).to_i }%)"
      end

      # --- Layout Definitions ---

      def create_makuhari_messe_layout(session)
        venue = session.event_seat_venues.first || session.event_seat_venues.create!(name: "Temp")
        venue.update!(name: "Makuhari Messe Event Hall, Chiba", total_row: 47, total_column: 62, aspect_ratio: "custom")
        venue.event_seat_sections.destroy_all

        specs = [
          { name: "Left Wing", price: 200, r: 11, c: 1, rs: 11, cs: 25, rot: 270, rb: [5, 5, 5], cb: [5, 5, 5, 5, 5, 5] },
          { name: "Center Left", price: 250, r: 4, c: 21, rs: 26, cs: 10, rot: 0, rb: [6, 6, 6, 6], cb: [6, 6, 6], empty: [[3, 0]] },
          { name: "Center Right", price: 250, r: 4, c: 33, rs: 26, cs: 10, rot: 0, rb: [6, 6, 6, 6], cb: [6, 6, 6], empty: [[3, 2]] },
          { name: "Right Wing", price: 200, r: 11, c: 38, rs: 11, cs: 25, rot: 90, rb: [5, 5, 5], cb: [5, 5, 5, 5, 5, 5] },
          { name: "Left Back Wing", price: 150, r: 33, c: 9, rs: 10, cs: 20, rot: 15, rb: [3, 3], cb: [3, 3, 3] },
          { name: "Right Back Wing", price: 150, r: 33, c: 35, rs: 10, cs: 20, rot: 345, rb: [3, 3], cb: [3, 3, 3] }
        ]
        specs.each do |s|
          section = venue.event_seat_sections.create!(
            name: s[:name], price: s[:price], start_row: s[:r], start_column: s[:c],
            row_span: s[:rs], col_span: s[:cs], rotation: s[:rot],
            seat_row: s[:rb].sum + s[:rb].size - 1, seat_column: s[:cb].sum + s[:cb].size - 1
          )
          bulk_insert_seats(section, row_blocks: s[:rb], col_blocks: s[:cb], empty_blocks: s[:empty] || [])
        end
      end

      def create_yokohama_arena_layout(session)
        venue = session.event_seat_venues.first || session.event_seat_venues.create!(name: "Temp")
        venue.update!(name: "Yokohama Arena, Yokohama", total_row: 24, total_column: 42, aspect_ratio: "custom")
        venue.event_seat_sections.destroy_all

        specs = [
          { name: "Left Wing", price: 200, r: 14, c: 2, rs: 5, cs: 12, rot: 15, rb: [6, 6, 6], cb: [6, 6, 6], empty: [[0, 0], [0, 1], [1, 0]] },
          { name: "Center", price: 250, r: 16, c: 15, rs: 5, cs: 13, rot: 0, rb: [6, 6, 6], cb: [6, 3, 3, 6] },
          { name: "Right Wing", price: 200, r: 14, c: 29, rs: 5, cs: 12, rot: 345, rb: [6, 6, 6], cb: [6, 6, 6], empty: [[0, 1], [0, 2], [1, 2]] }
        ]
        specs.each do |s|
          section = venue.event_seat_sections.create!(
            name: s[:name], price: s[:price], start_row: s[:r], start_column: s[:c],
            row_span: s[:rs], col_span: s[:cs], rotation: s[:rot],
            seat_row: s[:rb].sum + s[:rb].size - 1, seat_column: s[:cb].sum + s[:cb].size - 1
          )
          bulk_insert_seats(section, row_blocks: s[:rb], col_blocks: s[:cb], empty_blocks: s[:empty] || [])
        end
      end

      def create_keio_arena_layout(session)
        venue = session.event_seat_venues.first || session.event_seat_venues.create!(name: "Temp")
        venue.update!(name: "Keio Arena Tokyo", total_row: 20, total_column: 20, aspect_ratio: "square")
        venue.event_seat_sections.destroy_all

        [
          { name: "Stage Front Seats [Premium]", price: 150, r: 2 },
          { name: "Stage Mid Seats [Fans]", price: 110, r: 8 },
          { name: "Stage Back Seats [Regular]", price: 80, r: 14 }
        ].each do |s|
          section = venue.event_seat_sections.create!(
            name: s[:name], price: s[:price], start_row: s[:r], start_column: 5,
            row_span: 5, col_span: 12, seat_row: 3, seat_column: 11
          )
          bulk_insert_seats(section, row_blocks: [3], col_blocks: [3, 3, 3])
        end
      end

      # --- Main Seeding Task ---

      superadmin = User.find_by(email: "s@s.com")
      return puts "⚠️ Superadmin not found" unless superadmin

      # 1. Ticket-Based Event
      ticket_event = Event.find_or_create_by!(slug: "the-idolm-ster-gakuen-the-2nd-period") do |e|
        e.title = "THE IDOLM@STER Gakuen The 2nd Period"
        e.status = :published; e.payment_status = :paid
        e.start_date = Date.new(2026, 5, 15); e.end_date = Date.new(2026, 6, 7)
        e.published = true; e.use_seat_ticketing = true; e.use_ticket = true
      end
      EventAssignment.find_or_create_by!(event: ticket_event, user: superadmin, role: :event_admin)
      wipe_event_data(ticket_event)

      [
        { name: "The 2nd Period H.I.F Senbatsushiken (Selection)", slug: "hif-selection", loc: "Makuhari Messe", ord: 1, layout: :makuhari, ratio: 0.9 },
        { name: "The 2nd Period Hatsuboshi IDOL FESTIVAL", slug: "hatsuboshi-fest", loc: "Yokohama Arena", ord: 2, layout: :yokohama, ratio: 0.6 }
      ].each do |data|
        session = EventSeatSession.find_or_initialize_by(event: ticket_event, name: data[:name])
        session.update!(slug: data[:slug], status: :published, location: data[:loc], order: data[:ord], start_datetime: Time.current, end_datetime: Time.current + 1.day)
        data[:layout] == :makuhari ? create_makuhari_messe_layout(session) : create_yokohama_arena_layout(session)
        seed_occupancy(ticket_event, session, data[:ratio])
        puts "✓ Seeded #{data[:name]}"
      end

      # 2. Visitor-Based Event
      visitor_event = Event.find_or_create_by!(slug: "the-idolm-ster-20th-anniversary-live") do |e|
        e.title = "THE IDOLM@STER 20th Anniversary LIVE"
        e.status = :published; e.payment_status = :paid
        e.start_date = Date.new(2026, 7, 24); e.end_date = Date.new(2026, 7, 26)
        e.published = true; e.use_seat_ticketing = true; e.use_ticket = false
      end
      EventAssignment.find_or_create_by!(event: visitor_event, user: superadmin, role: :event_admin)
      wipe_event_data(visitor_event)

      [
        { name: "(ALL) Dance", slug: "all-dance", ratio: 1.0 },
        { name: "(ALL) Band", slug: "all-band", ratio: 0.5 },
        { name: "(ALL) Call & Response", slug: "all-call-response", ratio: 0.9 }
      ].each_with_index do |data, i|
        session = EventSeatSession.find_or_initialize_by(event: visitor_event, name: data[:name])
        session.update!(slug: data[:slug], status: :published, location: "Keio Arena", order: i+1, start_datetime: Time.current, end_datetime: Time.current + 1.day)
        create_keio_arena_layout(session)
        seed_occupancy(visitor_event, session, data[:ratio])
        puts "✓ Seeded #{data[:name]}"
      end

      puts "\n✅ ALL LAYOUTS SEEDED SUCCESSFULLY"
    end
  end
end