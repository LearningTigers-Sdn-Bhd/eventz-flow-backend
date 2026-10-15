
require_relative 'config/environment'

puts "Creating a new ticket without payment_status..."
ticket = Ticket.new(
  event: Event.first,
  ticket_type: TicketType.first,
  attendee_name: 'Test',
  attendee_email: 'test@example.com',
  status: :purchased
)

puts "Payment status: #{ticket.payment_status.inspect}"
puts "Valid? #{ticket.valid?}"
puts "Errors: #{ticket.errors.full_messages}"

if ticket.save
  puts "Saved successfully! Payment status: #{ticket.payment_status}"
else
  puts "Failed to save."
end
