class TicketPaymentService
  class << self
    # Create a cash payment (walk-in)
    def create_cash_payment(ticket:, amount:, received_by:, notes: nil)
      TicketPayment.create!(
        ticket: ticket,
        amount: amount,
        payment_method: "cash",
        status: "paid",
        paid_at: Time.current,
        received_by: received_by,
        notes: notes
      ).tap do
        ticket.update!(payment_status: "paid")
      end
    end

    # Create an online payment (pending gateway confirmation)
    def create_online_payment(ticket:, amount:, gateway:, gateway_payment_id: nil)
      TicketPayment.create!(
        ticket: ticket,
        amount: amount,
        gateway: gateway,
        gateway_payment_id: gateway_payment_id,
        status: "pending"
      )
    end

    # Create a complimentary/free payment record
    def create_comp_payment(ticket:)
      TicketPayment.create!(
        ticket: ticket,
        amount: 0,
        payment_method: "comp",
        status: "paid",
        paid_at: Time.current
      ).tap do
        ticket.update!(payment_status: "paid")
      end
    end
  end
end
