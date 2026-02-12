namespace :seat_ticketing do
  desc "Clean up expired checkout sessions and release seat locks"
  task cleanup_expired_sessions: :environment do
    expired_sessions = EventSeatCheckoutSession.where("created_at < ?", EventSeatCheckoutSession::LOCK_DURATION.ago)
    
    count = expired_sessions.count
    puts "Found #{count} expired checkout sessions."

    expired_sessions.find_each do |session|
      ActiveRecord::Base.transaction do
        # Release all seats locked by this session
        EventTicketSeat.where(locked_by_session_id: session.id).update_all(locked_by_session_id: nil)
        # Destroy the session
        session.destroy
      end
    end

    puts "Successfully cleaned up #{count} sessions and released associated locks."
  end
end
