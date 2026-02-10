module SeatTicketing
  class SyncService
    class << self
      def sync_section(section)
        return unless section.event&.use_ticket?

        ticket_type = section.ticket_type || find_or_create_ticket_type(section)
        session = section.event_seat_session
        
        # Update TicketType details
        ticket_type.update!(
          name: "#{session.name}: #{section.name}",
          price: section.price,
          quantity: calculate_section_quantity(section),
          seat_ticketing_type: :st_section,
          seat_ticketing_source_id: section.id,
          event_id: section.event.id
        )

        section.update_columns(ticket_type_id: ticket_type.id) if section.ticket_type_id != ticket_type.id
        
        # Also sync all groups and individual seats in this section as their base price might have changed
        section.event_seat_groups.each { |g| sync_group(g) }
        section.event_ticket_seats.left_outer_joins(:event_seat_group_assignment)
                                  .where(event_seat_group_assignments: { id: nil })
                                  .where('extra_price > 0')
                                  .each { |s| sync_seat(s) }
      end

      def sync_group(group)
        return unless group.event&.use_ticket?

        ticket_type = group.ticket_type || find_or_create_ticket_type(group)
        section = group.event_seat_section
        session = section.event_seat_session

        ticket_type.update!(
          name: "#{session.name}: #{section.name} - #{group.name}",
          price: section.price + group.extra_price,
          quantity: group.event_ticket_seats.count,
          seat_ticketing_type: :st_group,
          seat_ticketing_source_id: group.id,
          event_id: group.event.id
        )

        group.update_columns(ticket_type_id: ticket_type.id) if group.ticket_type_id != ticket_type.id
        
        # Ensure all seats in this group have their ticket_type_id synced
        group.event_ticket_seats.update_all(ticket_type_id: ticket_type.id)
      end

      def sync_seat(seat)
        return unless seat.event&.use_ticket?
        
        # If seat is in a group, it follows group sync
        if seat.event_seat_group.present?
          sync_group(seat.event_seat_group)
          return
        end

        # If no extra price, it belongs to the section ticket
        if seat.extra_price <= 0
          seat.update_columns(ticket_type_id: seat.event_seat_section.ticket_type_id)
          sync_section(seat.event_seat_section)
          return
        end

        # Individual premium seat
        ticket_type = seat.ticket_type || find_or_create_ticket_type(seat)
        section = seat.event_seat_section
        session = section.event_seat_session

        ticket_type.update!(
          name: "#{session.name}: #{section.name} - #{seat.name}",
          price: section.price + seat.extra_price,
          quantity: 1,
          seat_ticketing_type: :st_individual,
          seat_ticketing_source_id: seat.id,
          event_id: seat.event.id
        )

        seat.update_columns(ticket_type_id: ticket_type.id) if seat.ticket_type_id != ticket_type.id
      end

      def sync_from_ticket_type(ticket_type)
        return unless ticket_type.seat_ticketing_type.present?
        
        source_id = ticket_type.seat_ticketing_source_id
        return if source_id.blank?

        case ticket_type.seat_ticketing_type.to_sym
        when :st_section
          section = EventSeatSection.find_by(id: source_id)
          section&.update_columns(price: ticket_type.price)
          # Trigger update for all nested items
          section&.event_seat_groups&.each { |g| sync_group(g) }
          section&.event_ticket_seats&.left_outer_joins(:event_seat_group_assignment)
                                    &.where(event_seat_group_assignments: { id: nil })
                                    &.where('extra_price > 0')
                                    &.each { |s| sync_seat(s) }
        when :st_group
          group = EventSeatGroup.find_by(id: source_id)
          if group
            section_price = group.event_seat_section.price
            new_extra_price = [ticket_type.price - section_price, 0].max
            group.update_columns(extra_price: new_extra_price)
          end
        when :st_individual
          seat = EventTicketSeat.find_by(id: source_id)
          if seat
            section_price = seat.event_seat_section.price
            new_extra_price = [ticket_type.price - section_price, 0].max
            seat.update_columns(extra_price: new_extra_price)
          end
        end
      end

      private

      def find_or_create_ticket_type(source)
        # Try finding by metadata if ID not present on source
        TicketType.find_by(
          seat_ticketing_type: ticket_type_type_for(source),
          seat_ticketing_source_id: source.id
        ) || TicketType.create!(
          name: "Pending Sync",
          price: 0,
          quantity: 0,
          event_id: source.event.id,
          seat_ticketing_type: ticket_type_type_for(source),
          seat_ticketing_source_id: source.id,
          status: :published,
          hidden: false
        )
      end

      def ticket_type_type_for(source)
        case source
        when EventSeatSection then :st_section
        when EventSeatGroup then :st_group
        when EventTicketSeat then :st_individual
        end
      end

      def calculate_section_quantity(section)
        # Standard seats are those not in a group AND with extra_price <= 0
        section.event_ticket_seats
               .left_outer_joins(:event_seat_group_assignment)
               .where(event_seat_group_assignments: { id: nil })
               .where('extra_price <= 0')
               .count
      end
    end
  end
end
