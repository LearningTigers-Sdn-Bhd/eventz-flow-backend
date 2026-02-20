module SeatTicketing
  class SeatGeneratorService
    class << self
      def generate(section, config = {})
        row_blocks = (config[:row_blocks] || [section.seat_row]).map(&:to_i)
        col_blocks = (config[:col_blocks] || [section.seat_column]).map(&:to_i)
        row_gap = (config[:row_gap] || 0).to_i
        col_gap = (config[:col_gap] || 0).to_i
        exclusions = config[:exclusions] || [] # Array of {r, c}

        ActiveRecord::Base.transaction do
          # 1. Identify protected seats (sold or locked)
          protected_seats = section.event_ticket_seats.where.not(ticket_id: nil)
                                   .or(section.event_ticket_seats.where.not(visitor_id: nil))
                                   .or(section.event_ticket_seats.where.not(locked_by_session_id: nil))
          
          protected_coords = protected_seats.pluck(:row_set, :col_set).map { |r, c| "#{r}-#{c}" }

          # 2. Delete all other seats
          section.event_ticket_seats.where.not(id: protected_seats.pluck(:id)).delete_all

          # 3. Generate new seat data
          seat_data = []
          actual_row = 1
          
          row_blocks.each_with_index do |r_count, r_idx|
            r_count.times do |r_in_block|
              actual_col = 1
              col_blocks.each_with_index do |c_count, c_idx|
                c_count.times do |c_in_block|
                  # Skip if in exclusions OR if a protected seat already exists here
                  unless excluded?(actual_row, actual_col, exclusions) || protected_coords.include?("#{actual_row}-#{actual_col}")
                    seat_data << {
                      event_seat_section_id: section.id,
                      name: "#{section.name}-#{actual_row}#{col_name(actual_col)}",
                      row_set: actual_row,
                      col_set: actual_col,
                      created_at: Time.current,
                      updated_at: Time.current
                    }
                  end
                  actual_col += 1
                end
                actual_col += col_gap if c_idx < col_blocks.size - 1
              end
              actual_row += 1
            end
            actual_row += row_gap if r_idx < row_blocks.size - 1
          end

          # 4. Insert new seats
          if seat_data.any?
            EventTicketSeat.insert_all(seat_data)
          end

          # 5. Trigger sync for the section to update ticket types
          SyncService.sync_section(section)
        end
      end

      private

      def excluded?(r, c, exclusions)
        exclusions.any? { |e| e[:r].to_i == r && e[:c].to_i == c } ||
        exclusions.any? { |e| e['r'].to_i == r && e['c'].to_i == c }
      end

      def col_name(col)
        name = ""
        temp_col = col
        while temp_col > 0
          temp_col, remainder = (temp_col - 1).divmod(26)
          name = (65 + remainder).chr + name
        end
        name
      end
    end
  end
end
